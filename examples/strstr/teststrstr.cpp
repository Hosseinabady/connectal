#include <stdio.h>
#include <sys/mman.h>
#include <stdlib.h>
#include <unistd.h>
#include <assert.h>
#include <semaphore.h>
#include "StdDMAIndication.h"

#include "StrstrIndicationWrapper.h"
#include "StrstrRequestProxy.h"
#include "GeneratedTypes.h"
#include "DMARequestProxy.h"

sem_t test_sem;
unsigned int sw_match_cnt = 0;
unsigned int hw_match_cnt = 0;
extern Directory *pdir;

class StrstrIndication : public StrstrIndicationWrapper
{
public:
  StrstrIndication(unsigned int id) : StrstrIndicationWrapper(id){};

  virtual void searchResult (int v){
    fprintf(stderr, "searchResult = %d\n", v);
    if (v == -1)
      sem_post(&test_sem);
    else 
      hw_match_cnt++;
  }
};

void compute_borders(const char *x, int *border, int m)
{
  border[0] = -1;
  for(int i = 1; i <=m; i++){
    int j = border[i-1];
    while ((j>=0) && (x[i] != x[j+1]))
      j = border[j];
    border[i] = j+1;
  }
}

void compute_MP_next(const char *x, int *MP_next, int m)
{
  MP_next[1] = 0;
  int j = 0;
  for(int i = 1; i <= m; i++){
    while ((j>0) && (x[i] != x[j]))
      j = MP_next[j];
    j = j+1;
    MP_next[i+1] = j;
  }
}

void MP(const char *x, const char *t, int *MP_next, int m, int n)
{
  int i = 1;
  int j = 1;
  while (j <= n) {
    while ((i==m+1) || ((i>0) && (x[i-1] != t[j-1]))){
      //fprintf(stderr, "char mismatch %d %d MP_next[i]=%d\n", i,j,MP_next[i]);
      i = MP_next[i];
    }
    //fprintf(stderr, "   char match %d %d\n", i, j);
    i = i+1;
    j = j+1;
    if (i==m+1){
      fprintf(stderr, "%s occurs in t at position %d\n", x, j-i);
      i = 1;
      sw_match_cnt++;
    }
  }
  fprintf(stderr, "MP exiting\n");
}

int main(int argc, const char **argv)
{

  pdir->print();

  StrstrRequestProxy *device = 0;
  DMARequestProxy *dma = 0;
  
  StrstrIndication *deviceIndication = 0;
  DMAIndication *dmaIndication = 0;

  fprintf(stderr, "%s %s\n", __DATE__, __TIME__);
  device = new StrstrRequestProxy(IfcNames_StrstrRequest);
  dma = new DMARequestProxy(IfcNames_DMARequest);

  deviceIndication = new StrstrIndication(IfcNames_StrstrIndication);
  dmaIndication = new DMAIndication(dma, IfcNames_DMAIndication);

  if(sem_init(&test_sem, 1, 0)){
    fprintf(stderr, "failed to init test_sem\n");
    return -1;
  }

  pthread_t tid;
  fprintf(stderr, "creating exec thread\n");
  if(pthread_create(&tid, NULL,  portalExec, NULL)){
   fprintf(stderr, "error creating exec thread\n");
   exit(1);
  }

  if(1){
    fprintf(stderr, "simple tests\n");
    PortalAlloc *needleAlloc;
    PortalAlloc *haystackAlloc;
    PortalAlloc *mpNextAlloc;
    unsigned int alloc_len = 16 << 2;
    
    dma->alloc(alloc_len, &needleAlloc);
    dma->alloc(alloc_len, &haystackAlloc);
    dma->alloc(alloc_len, &mpNextAlloc);

    char *needle = (char *)mmap(0, alloc_len, PROT_READ|PROT_WRITE|PROT_EXEC, MAP_SHARED, needleAlloc->header.fd, 0);
    char *haystack = (char *)mmap(0, alloc_len, PROT_READ|PROT_WRITE|PROT_EXEC, MAP_SHARED, haystackAlloc->header.fd, 0);
    int *mpNext = (int *)mmap(0, alloc_len, PROT_READ|PROT_WRITE|PROT_EXEC, MAP_SHARED, mpNextAlloc->header.fd, 0);
    
    unsigned int ref_needleAlloc = dma->reference(needleAlloc);
    unsigned int ref_haystackAlloc = dma->reference(haystackAlloc);
    unsigned int ref_mpNextAlloc = dma->reference(mpNextAlloc);

    const char *needle_text = "ababab";
    const char *haystack_text = "acabcabacababacababababababcacabcabacababacabababc";
    
    assert(strlen(haystack_text) < alloc_len);
    assert(strlen(needle_text)*4 < alloc_len);

    strncpy(needle, needle_text, alloc_len);
    strncpy(haystack, haystack_text, alloc_len);

    int needle_len = strlen(needle);
    int haystack_len = strlen(haystack);
    int border[needle_len+1];

    compute_borders(needle, border, needle_len);
    compute_MP_next(needle, mpNext, needle_len);
    
    assert(mpNext[1] == 0);
    assert(border[1] == 0);
    for(int i = 2; i < needle_len+1; i++)
      assert(mpNext[i] == border[i-1]+1);

    MP(needle, haystack, mpNext, needle_len, haystack_len);
    
    dma->dCacheFlushInval(needleAlloc, needle);
    dma->dCacheFlushInval(mpNextAlloc, mpNext);

    device->search(ref_needleAlloc, ref_haystackAlloc, ref_mpNextAlloc, needle_len, haystack_len);
    sem_wait(&test_sem);

    close(needleAlloc->header.fd);
    close(haystackAlloc->header.fd);
    close(mpNextAlloc->header.fd);
  }


#ifdef MMAP_HW  
  if(0){
    fprintf(stderr, "benchmarks\n");
    PortalAlloc *needleAlloc;
    PortalAlloc *haystackAlloc;
    PortalAlloc *mpNextAlloc;
    const char *needle_text = "I have control\n";
    unsigned int BENCHMARK_INPUT_SIZE = 1024 * 1024;
    unsigned int haystack_alloc_len = BENCHMARK_INPUT_SIZE;
    unsigned int needle_alloc_len = strlen(needle_text);
    unsigned int mpNext_alloc_len = needle_alloc_len*4;
    
    dma->alloc(needle_alloc_len, &needleAlloc);
    dma->alloc(haystack_alloc_len, &haystackAlloc);
    dma->alloc(mpNext_alloc_len, &mpNextAlloc);

    char *needle = (char *)mmap(0, needle_alloc_len, PROT_READ|PROT_WRITE|PROT_EXEC, MAP_SHARED, needleAlloc->header.fd, 0);
    char *haystack = (char *)mmap(0, haystack_alloc_len, PROT_READ|PROT_WRITE|PROT_EXEC, MAP_SHARED, haystackAlloc->header.fd, 0);
    int *mpNext = (int *)mmap(0, mpNext_alloc_len, PROT_READ|PROT_WRITE|PROT_EXEC, MAP_SHARED, mpNextAlloc->header.fd, 0);

    unsigned int ref_needleAlloc = dma->reference(needleAlloc);
    unsigned int ref_haystackAlloc = dma->reference(haystackAlloc);
    unsigned int ref_mpNextAlloc = dma->reference(mpNextAlloc);

    FILE* fp = fopen("/dev/urandom", "r");
    size_t rv = fread(haystack, 1, BENCHMARK_INPUT_SIZE, fp);
    strncpy(needle, needle_text, needle_alloc_len);
    
    int needle_len = strlen(needle);
    int haystack_len = haystack_alloc_len;
    int border[needle_len+1];

    compute_borders(needle, border, needle_len);
    compute_MP_next(needle, mpNext, needle_len);

    assert(mpNext[1] == 0);
    assert(border[1] == 0);
    for(int i = 2; i < needle_len+1; i++)
      assert(mpNext[i] == border[i-1]+1);

    MP(needle, haystack, mpNext, needle_len, haystack_len);

    dma->dCacheFlushInval(needleAlloc, needle);
    dma->dCacheFlushInval(mpNextAlloc, mpNext);

    device->search(ref_needleAlloc, ref_haystackAlloc, ref_mpNextAlloc, needle_len, haystack_len);
    sem_wait(&test_sem);

    close(needleAlloc->header.fd);
    close(haystackAlloc->header.fd);
    close(mpNextAlloc->header.fd);
  }
#endif

  fprintf(stderr, "sw_match_cnt=%d, hw_match_cnt=%d\n", sw_match_cnt, hw_match_cnt);
  return (sw_match_cnt != hw_match_cnt);
}
