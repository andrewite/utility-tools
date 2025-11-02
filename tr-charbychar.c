#include <unistd.h>
#include <stdio.h>
#include <string.h>

int TreatEscapeStr(char *to,const char *from)
{
  if(from==NULL) from=to; 
  if(to==NULL) return 0;

  if(to==NULL) return 0;
  int fromPosition=0, toPosition=0; 
  int EscapeFlag=0;
  int EscapeHexFlag=0;
  int EscapeHexValue=0;
  const char *p=from;
  char *p2=to;
  while(*p)
  {
    if(*p=='\\')
    {
      if(EscapeFlag) { *p2++=*p ;EscapeFlag =0 ;}
      else {EscapeFlag=1; }
      fromPosition++; p++;
    }
    else if(EscapeFlag)
    {
      char nc=*p;
      if(EscapeHexFlag)
      {
        fromPosition++; p++;

        if((nc>='0')&&(nc<='9')) nc-='0';
        else if((nc>='A')&&(nc<='F')) nc-='A';
        else if((nc>='a')&&(nc<='f')) nc-='a';
        else 
        {
             *p2++=nc;
             EscapeHexFlag=0;
             EscapeFlag=0;
        }
 
        if(EscapeHexFlag==1)  //First Letter of HEX
        {
            EscapeHexValue=nc;
            EscapeHexFlag=2; 
        }
        else if(EscapeHexFlag==2) //Second Letter
        {  
           *p2++=EscapeHexValue*16+nc;
           EscapeHexFlag=0;
           EscapeFlag=0;
        }
      }  //end Hex Process
      else { 
         switch(*p)
         {
           case 'n':
             nc='\n'; break;
           case 'r':
             nc='\r'; break;
           case 't':
             nc='\t'; break;
           default:
             nc=*p  ; break;
           case 'x':
           case 'X':
             EscapeHexFlag=1; break;
         }
         p++;
         if(!EscapeHexFlag)
         {
            *p2++=nc;
            EscapeFlag=0;
         } 
      }//end Escape Process
    }
    else
    {
          *p2++=*p++;
    }
  }
  return p2-to;
}

PrintStrN(const char *p,int Len,int BlockLen)
{
   static int BufferedLen=0;
   //write(1,p,Len);  return;
   int i=0;
   for(i=0;i<Len;i++)
   {
     printf("%c",p[i]); 
     BufferedLen++;
   }
   if(BufferedLen>=BlockLen){fflush(stdout);BufferedLen=0;} 
}


int ReadNextChar(int fd,char *buffer,int len,int BlockLen)
{
   static char FileReadCacheBuffer[512];
   static int BufferRemain=0;
   static int DataLenInCacheBuffer=0;

   if(BufferRemain<=0) 
   {
     if(BlockLen>sizeof(FileReadCacheBuffer)) BlockLen=sizeof(FileReadCacheBuffer);
     DataLenInCacheBuffer=read(0,FileReadCacheBuffer,BlockLen);
     BufferRemain=DataLenInCacheBuffer;
   }
   if(DataLenInCacheBuffer<=0) return DataLenInCacheBuffer;
     buffer[0]=FileReadCacheBuffer[DataLenInCacheBuffer-BufferRemain];
   BufferRemain--;
   return 1;
}


struct BasePatternElement
{
   enum {
     Base,
     TextPattern,
     STARTPattern,
     ENDPattern,
     CharacterRangePattern,
     TimesPattern,
     BOOLPattern,
     ListPattern,
   }type;
   struct BasePatternElement *pNext; // will be removed , DO NOT USE
};


struct TextPatternElement
{
  struct BasePatternElement base;
  char * pTextPattern;
  int  PatternLength ;
};

struct EndPatternElement
{
  struct BasePatternElement base;
};

struct CharacterRangePatternElement
{
  struct BasePatternElement base;
  int nCharMemLen; //byte number ,0xf8: UTF-8, 0xf9: UNICODE-16
  unsigned int RangeStart;
  unsigned int RangeEnd;
};

struct TimesPatternElement
{
  struct BasePatternElement base;
  struct BasePatternElement * pPattern;
  int minimum;
  int maximum;
};

struct PatternPointorElement
{
  struct BasePatternElement base;
  struct BasePatternElement * pPattern;
};

struct ListPatternElement
{
  struct BasePatternElement base;
  struct BasePatternElement * pPattern;
  struct ListPatternElement * pPatternNext;
};

struct BOOLPatternElement
{
  struct BasePatternElement base;
  struct PatternPointorElement * pPatternHead;
  int BoolType; //  0 :or , 1 : and , 2: NOT

};

#define StartEndFlag_START (0x01)
#define StartEndFlag_END   (0x02)

#define MachResult_NotMach (-1)
#define NeedMoreCharToDetect (-2)

int MatchStrN(const char *buffer,const char *matchStr,int Len)
{
   return memcmp(buffer,matchStr,Len); // to support \X00
   //return strncmp(buffer,matchStr,Len);
}

int TimesPatternMatch(const char *buffer,int BufferLen,struct TimesPatternElement *pPattern, int StartEndFlag)
{
   int nMatchLength=0;
   int nCurrentMatchTimes=0;
   int nHaveMatchedLength=0;
   while(nCurrentMatchTimes<pPattern->maximum)
   {
     nMatchLength=TextPatternMatch(buffer, BufferLen,pPattern->pPattern); 
     //printf("TimesPattern nCurrentMatchTimes=%d bMatch=%d \n", nCurrentMatchTimes,bMatch);
     if(nMatchLength<=0) break;
     nCurrentMatchTimes++;
     nHaveMatchedLength+=nMatchLength;
     BufferLen-=nMatchLength;
   }
   //printf("TimesPattern nCurrentMatchTimes=%d nMatchLength=%d pPattern->minimum=%d \n", nCurrentMatchTimes,nMatchLength,pPattern->minimum);
   if(nCurrentMatchTimes<pPattern->minimum) return nMatchLength ;// -1: match false or -2 need more
   else if((StartEndFlag & StartEndFlag_END)||(nMatchLength!=NeedMoreCharToDetect))
       return nHaveMatchedLength; 
   return NeedMoreCharToDetect; // need more
}

//-1 for Not Match, -2 for Need more char to detect
int TextPatternMatch(const char *buffer,int BufferLen,struct TextPatternElement *pPattern)
{
   //printf("TextPatternMatch buffer=%s BufferLen=%d pPattern->PatternLength=%d \n", buffer,BufferLen,pPattern->PatternLength);
   if(BufferLen<pPattern->PatternLength)
   { if(0==memcmp(buffer,  pPattern->pTextPattern, BufferLen ))
       return NeedMoreCharToDetect; //Need more char to detect
     else return MachResult_NotMach;
   }
   if(0==memcmp(buffer,  pPattern->pTextPattern, pPattern->PatternLength ))
      return pPattern->PatternLength; 
   else return MachResult_NotMach;
}

int GetOneUTF8Character(const char *buffer,int BufferLen,int nCharLenOrType,unsigned int *pCharValue)
{
  // Not finished

  unsigned int CharValue=0;
  if(0xf8==nCharLenOrType) // pPattern->nCharMemLen        // UTF-8
    return 3;
  else if(0xf9==nCharLenOrType) // pPattern->nCharMemLen  //UNICODE-16
    return 2;

  if(pCharValue) *pCharValue=CharValue;
  return 3;
}

// Not support NeedMoreCharToDetect now
int CharacterRangePatternMatch(const char *buffer,int BufferLen,struct CharacterRangePatternElement *pPattern)
{
   if(BufferLen<(pPattern->nCharMemLen)) return -1;
   unsigned int CharValue=0;
   int nMatchLen=pPattern->nCharMemLen; 
   if(1==pPattern->nCharMemLen) CharValue=*((unsigned char*)buffer);
   else if(2==pPattern->nCharMemLen) CharValue=*((unsigned short*)buffer);
   else if(4==pPattern->nCharMemLen) CharValue=*((unsigned long*)buffer);
   else if(3==pPattern->nCharMemLen)
        CharValue=(*((unsigned char*)buffer))*256*256 + 
                 (*((unsigned char*)buffer+1))*256 +
                 (*((unsigned char*)buffer+2)) ;
   else if((0xf8==pPattern->nCharMemLen)||(0xf9==pPattern->nCharMemLen)) // UTF-8 or UNICODE-16
   {
          nMatchLen=GetOneUTF8Character(buffer,BufferLen,
                         pPattern->nCharMemLen,&CharValue);
          if(nMatchLen<0) return -1; 
   }
   else return MachResult_NotMach;

   if((CharValue>=pPattern->RangeStart)&&(CharValue<=pPattern->RangeEnd))
      return nMatchLen; 
   else return MachResult_NotMach;
}


// All the Pattern in list should be matched
int ListPatternMatch(const char *buffer,int BufferLen,struct ListPatternElement *pPattern, int StartEndFlag)
{
   int nMatchLen=0;
   int return_value=MachResult_NotMach;
   struct ListPatternElement *pPatternHead = pPattern ;
   while(pPatternHead)
   {
     return_value=PatternMatch(buffer,BufferLen,pPatternHead->pPattern,StartEndFlag) ;
     //printf("ListPatternMatch result=%d  nMatchLen=%d  BufferLen=%d\n", return_value, nMatchLen,BufferLen);
     if(return_value<0) return return_value;
     nMatchLen+=return_value;
     buffer+=return_value;
     BufferLen-=return_value;
     pPatternHead=pPatternHead->pPatternNext;
   }
   return nMatchLen;
}

//StartEndFlag : bit 0x1 : matching start : bit 0x2 matching end
//return Matched Length, -1 for Not Match, -2 for Need more char to detect
int PatternMatch(const char *buffer,int BufferLen,struct BasePatternElement *pPattern, int StartEndFlag)
{
   int return_value=MachResult_NotMach;
   //printf("PatternMatch BufferLen=%d  %d\n", BufferLen,__LINE__);
   if(TimesPattern==pPattern->type)
   {
      return_value= TimesPatternMatch(buffer,BufferLen,(struct TimesPatternElement *)pPattern,StartEndFlag) ;
      //printf("TimesPattern result=%d  \n", return_value);
      return return_value;
   }
   else if(TextPattern==pPattern->type)
     return TextPatternMatch(buffer,BufferLen,(struct TextPatternElement *)pPattern) ;
   else if(ListPattern==pPattern->type)
     return ListPatternMatch(buffer,BufferLen,(struct ListPatternElement *)pPattern,StartEndFlag) ;
   else if(STARTPattern==pPattern->type)
   {
      if(StartEndFlag & StartEndFlag_START) return_value=0;
      return  return_value;
   }
   else if(ENDPattern==pPattern->type)
   {
      if((StartEndFlag & StartEndFlag_END)&&(0==BufferLen)) return_value=0;
      return  return_value;
   }
   else if(CharacterRangePattern==pPattern->type)
   {
      return_value= CharacterRangePatternMatch(buffer,BufferLen,(struct CharacterRangePatternElement *)pPattern) ;
      return return_value;
   }
   return MachResult_NotMach ;//unkown Pattern
}

#define true (1)
#define false (0)
typedef int bool;
bool CheckIfMatchStrWithEndFlag( char* matchStr)
{
  int EscapeFlag=0;
  int EndWithEndLag=0;
  const char *p=matchStr;
  while(*p)
  {
    if(*p=='\\')
    {
      EscapeFlag =!EscapeFlag ;
      p++;
    }
    else if(EscapeFlag)
    {
      EscapeFlag = 0 ;
      p++;
    }
    else
    {
        if(*p=='$') EndWithEndLag=true;
        else EndWithEndLag=false;
        p++;
    }
  }
  
  return EndWithEndLag;
}


int FillMatchPattern(struct ListPatternElement *pHead,
                 struct ListPatternElement *pContentNode,
                 struct ListPatternElement *pEnd,
                 struct BasePatternElement *pContentPattern, 
                 struct TextPatternElement *pMainTextPattern,
                 struct BasePatternElement **pResultPtr, 
                 char* matchStr)
{
  pEnd->base.type=ListPattern;
  pEnd->pPatternNext=NULL;
  pContentNode->base.type=ListPattern;
  pContentNode->pPatternNext=pEnd;
  pContentNode->pPattern=pContentPattern;
  pHead->base.type=ListPattern;
  pHead->pPatternNext=pContentNode;
  int totalmatchStrLen=0;

  struct BasePatternElement *pResult=NULL; 
  if(matchStr[0]=='^'){
    pResult=(struct BasePatternElement *)pHead; 
    matchStr++; // remove "^"
  }
  if(CheckIfMatchStrWithEndFlag(matchStr)){
    matchStr[strlen(matchStr)-1]=0; // remove "$"
    if(NULL==pResult)pResult=(struct BasePatternElement *)pContentNode; 
  }else 
    pContentNode->pPatternNext=NULL ; // No End Flag
  if(NULL==pResult){
    //pResult=(BasePatternElement *)pContentNode; 
    pResult=pContentPattern;
  }

  pMainTextPattern->base.type=TextPattern;
  pMainTextPattern->base.pNext=NULL;
  int matchStrLen=TreatEscapeStr(matchStr,matchStr);
  totalmatchStrLen+=matchStrLen;
  pMainTextPattern->pTextPattern=matchStr;
  pMainTextPattern->PatternLength=matchStrLen;

  if(pResultPtr) *pResultPtr=pResult;
  return totalmatchStrLen;
}


int ProcessDataRemainInBufferAfterReadOver( char * buffer, int dataLen,const char * outputstr,int outputStrLen,int OneIOBlockLen, struct BasePatternElement * pPatternHead)
{

 int i=0;
 int StartEndFlag=StartEndFlag_END; // set END Flag
 int nMatchedLen=-1;
 int  dataLenInBuffer=dataLen;
 const char *p=buffer;
 while(dataLenInBuffer>0)
 {
   nMatchedLen=PatternMatch(p,dataLenInBuffer,pPatternHead,StartEndFlag); 
   // printf(" p=%s nMatchedLen: %d dataLenInBuffer %d  \n",p, nMatchedLen,dataLenInBuffer); 
   if(nMatchedLen>0)
   {
      int BufferNeedAdjustLen=nMatchedLen;
      PrintStrN(outputstr,outputStrLen,OneIOBlockLen); 
      p+=BufferNeedAdjustLen;
      dataLenInBuffer-=BufferNeedAdjustLen;
    // printf("  nMatchedLen: %d dataLenInBuffer %d  ",nMatchedLen,dataLenInBuffer); 

   }else
   {
        PrintStrN(p,1,OneIOBlockLen); 
        p++;
        dataLenInBuffer--;
        //printf("  %p  %p %c %s \n",p,buffer,buffer[0],buffer); 
   }

 }

 

  /*  HAVE FIXED

   // This is a work around code , Fix me please.
   // We do a more time match after all finish with StopFlag setted 
   // There is error when regex pattern is \(.abc\)\|$ , it will be ouput double time when match abc$
 

   nMatchedLen=PatternMatch(buffer,dataLenInBuffer,pPatternHead,StartEndFlag); 
   if(nMatchedLen>0)
   {
      PrintStrN(outputstr,outputStrLen,OneIOBlockLen); 
      dataLenInBuffer=0;
   }

  */ // work around code end. below is normal code



   PrintStrN(buffer,dataLenInBuffer,OneIOBlockLen); 



  return 1;
}

void OutputMatchedPatternResult(char * buffer, struct ListPatternElement *pOutPatternList,int OneIOBlockLen)
{
  while(pOutPatternList)
  {
   if(TextPattern==pOutPatternList->pPattern->type)
   {
      struct TextPatternElement *pElement= (struct TextPatternElement *)pOutPatternList->pPattern;
      PrintStrN(pElement->pTextPattern,pElement->PatternLength,OneIOBlockLen); 
   }
   else 
   {
      int len=0;
      //len=GetmatchlenOf( pOutPatternList->pPattern );
      PrintStrN(buffer,len,OneIOBlockLen); 
   }
   pOutPatternList=pOutPatternList->pPatternNext;
  }
   
}

void OutputOneUnMatchDataInBuffer(char * buffer, char* *pp,int *pdataLenInBuffer,int OneIOBlockLen)
{
      PrintStrN(buffer,1,OneIOBlockLen); 
      memcpy(&buffer[0],&buffer[1],*pdataLenInBuffer);
      (*pp)--;
      (*pdataLenInBuffer)--;
}

main(int argc, char *argv[])
{
 char bufferRead[11];
 char buffer[1024*6];
 int bufferLen=sizeof(buffer);
 if(argc<3)
 {
   printf("USAGE: pattern replace_string cache_length\n");
   return 2;
 }

 char *outputstr=argv[2];
 int outputStrLen=strlen(outputstr);
 outputStrLen=TreatEscapeStr(outputstr,argv[2]);

 //int OneIOBlockLen=512; //512 is more quick, but not response slowly ,so we use 1 
 int OneIOBlockLen=1; //For 1, speed is slow than 512 ,but response more fastly

 if(argc>=4)OneIOBlockLen=atoi(argv[3]);


 struct BasePatternElement * pPatternHead=NULL;

 struct EndPatternElement PT_StartPattern;
 PT_StartPattern.base.type=STARTPattern;
 struct EndPatternElement PT_EndPattern;
 PT_EndPattern.base.type=ENDPattern;
 struct TextPatternElement PT_TextPattern;

 struct TimesPatternElement PT_TimesPattern;
 PT_TimesPattern.base.type=TimesPattern;
 PT_TimesPattern.base.pNext=NULL;
 PT_TimesPattern.pPattern=(struct BasePatternElement *)&PT_TextPattern;
 PT_TimesPattern.minimum=1;
 PT_TimesPattern.maximum=1;

 struct BasePatternElement *pContentPattern=(struct BasePatternElement *)&PT_TimesPattern;

 struct ListPatternElement EndListPatternElement;
 EndListPatternElement.pPattern=(struct BasePatternElement *)&PT_EndPattern;
 struct ListPatternElement ContentListPatternElement;
 struct ListPatternElement HeadListPatternElement;
 HeadListPatternElement.pPattern=(struct BasePatternElement *)&PT_StartPattern;

 int matchStrLen=FillMatchPattern(&HeadListPatternElement,&ContentListPatternElement,
       &EndListPatternElement,pContentPattern,&PT_TextPattern, &pPatternHead,argv[1]);

 if(matchStrLen > bufferLen-2) 
 {
   printf("ERROR! pattern is too long.\n");
   return 3;
 }



 char *bufferHead=buffer;
 char *p=buffer;
 int  dataLenInBuffer=0;
 int c=ReadNextChar(0,bufferRead,1,OneIOBlockLen);

 int  i=0;
 int nPreReadLen=0;
 nPreReadLen=matchStrLen-1; //should -1 to do match testing when =len
 if(argc>=5)nPreReadLen=atoi(argv[4]);
 // There is a bug in Pre read code , when input data is less that nPreReadLen
 // so we set it as 0 to turn pre read off
 // so buffer len is equal with matchLen,  times pattern can't be matched
 for(i=0;i<nPreReadLen;i++) {
    *p++=bufferRead[0];
    dataLenInBuffer++;
    c=ReadNextChar(0,bufferRead,1,OneIOBlockLen); 
    if(c<=0) break;
 };

 int nMatchedLen=0;
 int StartEndFlag=StartEndFlag_START;
 while(c)
 {
   *p++=bufferRead[0];
   dataLenInBuffer++;
   int matchLenforcmp=matchStrLen<dataLenInBuffer?matchStrLen:dataLenInBuffer;
   nMatchedLen=PatternMatch(buffer,dataLenInBuffer,pPatternHead,StartEndFlag); 
   //if(0==strncmp(buffer,matchStr,matchLenforcmp)) nMatchedLen=matchLenforcmp; //=matchStrLen;
   if(nMatchedLen>0)
   {
      //int BufferNeedAdjustLen=matchStrLen;
      int BufferNeedAdjustLen=nMatchedLen;
      PrintStrN(outputstr,outputStrLen,OneIOBlockLen); 
      memcpy(&buffer[0],&buffer[matchStrLen],dataLenInBuffer-BufferNeedAdjustLen);
      p-=BufferNeedAdjustLen;
      dataLenInBuffer-=BufferNeedAdjustLen;

   }else if(1&&(nMatchedLen==MachResult_NotMach)) //Not Match ,try evry next char in buffer 
   {  // ok now ?//segment fault ,so turn it off
      while(MachResult_NotMach==PatternMatch(buffer,dataLenInBuffer,pPatternHead,StartEndFlag) )
      {  
	OutputOneUnMatchDataInBuffer(buffer, &p, &dataLenInBuffer, OneIOBlockLen);
      }  
      // maybe we should read more data into buffer here tp avoid segment fault?, NOT
      // shuld NOT read !!!!
   }
   else  //==NeedMoreCharToDetect) //Need more char to detect
   {
     if(p>=bufferHead+matchStrLen)
     {
        PrintStrN(buffer,1,OneIOBlockLen); 
        memcpy(&buffer[0],&buffer[1],dataLenInBuffer);
        p--;dataLenInBuffer--;
        //printf("  %p  %p %c %s \n",p,buffer,buffer[0],buffer); 
     }
   }
   c=ReadNextChar(0,bufferRead,1,OneIOBlockLen);
   StartEndFlag=0;
      //printf("  read: %c %d  ",bufferRead[0],c); 
      //PrintStrN(buffer,dataLenInBuffer); 
      //printf(" \n "); 
 }

  ProcessDataRemainInBufferAfterReadOver(buffer, dataLenInBuffer, outputstr,outputStrLen,OneIOBlockLen,pPatternHead); 
 

}
