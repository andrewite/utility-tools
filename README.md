# utility-tools
several tools:
1) nc.srv
   one line command to get a simple web server :
     nc.srv -Lp 8080 -c "read a b c;echo HTTP/1.1 200 OK ;echo ; cat .\$b "
    or use below to support folder list
     nc.srv -Lp 8080 -c "read a b c;echo HTTP/1.1 200 OK ;echo ; cat .\$b 2>/dev/null; [ \$? = 0 ] || ls -l \$(dirname .\$b.);"

   
