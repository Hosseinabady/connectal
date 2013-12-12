// library header files
#include "portal.h"

// generated header files
#include "SayWrapper.h"
#include "SayProxy.h"

sem_t echo_sem;

class MySay : public SayWrapper
{
  virtual void say(unsigned long v){
    fprintf(stderr, "say(%ld)\n", v);
    sem_post(&echo_sem);
  }
  virtual void say2(unsigned long a, unsigned long b){
    fprintf(stderr, "say2(%ld, %ld)\n", a,b);
    sem_post(&echo_sem);
  }
  MySay(int id) : SayWrapper(id){}
}

int main(int argc, const char **argv)
{
  loadPortalDirectory();

  SayProxy *sayProxy = new SayProxy(1008);
  MySay *sayWrapper = new MySay(7); 

  pthread_t tid;
  if(pthread_create(&tid, NULL,  portalExec, NULL)){
   fprintf(stderr, "error creating exec thread\n");
   exit(1);
  }

  if(sem_init(&echo_sem, 1, 0)){
    fprintf(stderr, "failed to init echo_sem\n");
    return -1;
  }

  sayProxy->say(0);
  sem_wait(&echo_sem);

  sayProxy->say2(1,2);
  sem_wait(&echo_sem);

}
