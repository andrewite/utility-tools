#!/bin/bash

## this script will generate a new nc as a server. 
## If you want nc execute -e command only once, please use the old one.
## in this version , -e is similar to -c .
## example:  -e " echo count; ls /usr/bin | wc " 


## below is the step for you to compile nc.srv 

#git clone git@github.com:H74N/netcat-binaries
git clone https://github.com/H74N/netcat-binaries
cd netcat-binaries

 sed "s/int dolisten (rad, rp, lad, lp)$/ USHORT o_forklisten = 0;\\n void waitchild(int);\\n int AddNewSocketSocketPidPair(int,int);\\n int dolisten (rad, rp, lad, lp)/" -i netcat.c


 sed "s/rr = accept (nnetfd, (SA \*)remend, &x);/signal(SIGCHLD,waitchild); while(1){ rr = accept (nnetfd, (SA *)remend, \&x);if(o_forklisten<=0) break; int newpid=fork(); if(newpid==0) break ;  AddNewSocketSocketPidPair(rr,newpid); };/" -i netcat.c


 sed "s/  execl (pr00gie, p, NULL);$/ if(pr00gi_c){ system(pr00gi_c);return;} execl (pr00gie, p, NULL); /;s/  bail (\"exec %s failed\", pr00gie);//"  -i netcat.c

sed "s/^      case 'e':\t\t/\t case 'c':pr00gie=pr00gi_c=optarg;break;\tcase 'L':o_forklisten++;o_listen++; break;\\n \tcase 'e':/"   -i netcat.c

sed "s/^char \* pr00gie = NULL;	/\\n char *pr00gi_c=NULL;char *pr00gie = NULL;	/g"   -i netcat.c


sed "s/ae:g:G:hi:lno:p:rs:tuvw:z/ac:e:g:G:hi:lLno:p:rs:tuvw:z/"  -i netcat.c

sed s"/^	-e prog		/\\t-L fork \\t\\t fork when listen\\\\n\\\\\\n\\t-c cmd\\t\\t\\\\n\\\\\\n\\t-e prog/"   -i netcat.c




cat >> netcat.c <<EOF 

struct SocketPidPair{
  int iSocket;
  int pid;
  struct SocketPidPair * next ;
};


struct SocketPidPair * pSocketPidPairHead = NULL ;

int AddNewSocketSocketPidPair(int sck,int pid)
{
  struct SocketPidPair * p = malloc(sizeof(struct SocketPidPair));
  if(!p) return -1;
  p->iSocket = sck ;
  p->pid = pid;
  p->next = pSocketPidPairHead ;
  pSocketPidPairHead = p ;
  return 0;
}

void waitchild(int arg)
{
   int status = 0 ;

   int pid=wait(&status);

   struct SocketPidPair * pParent = NULL ;
   struct SocketPidPair * p = pSocketPidPairHead ;
   while(p)
   {
     if(p->pid==pid) break;
     pParent=p;
     p=p->next;
   }
  
   if(p){
     // printf("closing sock:%p %d \n", p->next,p->iSocket);
     //  if(pParent) printf("pParent:%p p %p next %p \n", pParent,p,pParent->next);
     shutdown(p->iSocket,SHUT_RDWR);
     close(p->iSocket);
     if(pParent) pParent->next=p->next ;
       else pSocketPidPairHead=p->next ; 
     free(p);
   }

   return ;
}

EOF

#make $yoursystem
#example
make linux


## now you can run below command to get a simple http server

# sudo netcat-binaries/nc -l -p 80 -e "echo HTTP/1.1 200 OK;echo ;head -1 | cut -d\\  -f2 |xargs cat "

