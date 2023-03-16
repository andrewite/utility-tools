#!/bin/bash
Help()
{
  echo usage: $0 cmd arg1 arg2 ...
}

python_web_simple_server()
{
  if [ ! "$WWW_BASE" ] ;then
    export WWW_BASE=$HOME 
  fi
  if [ ! "$WWW_PORT" ] ;then
    export WWW_PORT=8080 
  fi
  if [ ! "$WWW_LOG" ] ;then
    export WWW_LOG=/dev/null
  fi
  if [ ! "$WWW_FUN_GET_MIMETYPE" ] ;then
    export WWW_FUN_GET_MIMETYPE=echo\ Content-Type:\ text/html\;charset=utf-8
  fi

echo -e "import os\\nimport SocketServer\\nclass ThreadingTCPServer(SocketServer.ThreadingMixIn, SocketServer.TCPServer):\\n pass\\nclass Socks5Server(SocketServer.StreamRequestHandler):\\n def Read(self):\\n  Method=\"\"\\n  while True :\\n   c=self.connection.recv(1)\\n   if c == ' ' :\\n    break \\n   Method += c\\n  return Method\\n def handle(self):\\n  print 'connection from ', self.client_address\\n  sock = self.connection\\n  Method=self.Read()\\n  GETSTR=self.Read()\\n  pip = os.popen(\"export GETSTR=\" + GETSTR + \";              bash -c \\\" Head() { echo HTTP/1.1 200 OK; echo Cache-Control: max-age=170100100 ; } ; GETSTRFILE=\\\$WWW_BASE\\\$(echo \\\$GETSTR | sed s/?.*// | sed s/%/\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\x/g |xargs -i echo -e {} | sed \\\\\\\\\\\"s#.*/\\\\.\\\\./.*#/error.html#\\\\\\\\\\\" ) ;echo \\\$GETSTR >> \\\$WWW_LOG ; if echo \\\$GETSTR | grep -i \\\\\\\\.css\\\\\\\\$  > /dev/null ; then echo HTTP/1.1 200 OK; echo content-type: text/css ;echo; cat \\\$GETSTRFILE ; elif echo \\\$GETSTR | grep -i \\\\\\\\.html\\\\\\\\$  > /dev/null ; then echo HTTP/1.1 200 OK; echo Content-Type: text/html\\;charset=utf-8 ;echo; cat \\\$GETSTRFILE ;  else Head; export WWW_REQUEST_URI=\\\$GETSTR; \\\$WWW_FUN_GET_MIMETYPE ; echo ; echo \\\$GETSTRFILE | sed s/%/\\\\\\\\x/g |xargs -i echo -e {} | xargs -i cat {}; fi \\\"             \" )\\n  while True:\\n   data=pip.read(1024)\\n   if data.__len__()==0 :\\n    pip.close()\\n    break \\n   sock.send(data)\\nserver = ThreadingTCPServer((\"\", $WWW_PORT), Socks5Server)\\nserver.allow_reuse_address = True\\nserver.serve_forever()\\n\\n" | python

}

python_web()
{
  python_web_simple_server $*
}


if [ "$1" ] ; then
  $1
  exit $?
else
 Help
fi
