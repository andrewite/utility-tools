#!/bin/bash


g_SendFirefoxMarionetteCmd_Index=0;
SendFirefoxMarionetteCmd()
{
  local CMD="$1"
  local VALUE="$2"
  local PORT="$3"

  g_SendFirefoxMarionetteCmd_Index=$(($g_SendFirefoxMarionetteCmd_Index +1))

  local Str="[0,$g_SendFirefoxMarionetteCmd_Index,\"$CMD\",{$VALUE}]"
  local StrLen=$(echo -n "$Str" | wc -c )
  echo -n "$StrLen:$Str" 
}

OpenURL()
{
  local URL="$1"
  local PORT="$2"
  SendFirefoxMarionetteCmd  "WebDriver:Navigate"  "\"url\":\"$URL\""  $PORT  
}

ExecuteScript()
{
  local Script="$1"
  local PORT="$2"
  SendFirefoxMarionetteCmd "WebDriver:ExecuteScript"  "\"args\":[],\"script\":\"$Script\""   $PORT  
}

if [ "$1" == "RUN" ] ;then shift;$@;exit;fi
if [ "$1" == "--help" ] ;then HELP; exit;fi


quiet_mode="--headless"; if [ "$1" == "--show" ] ;then unset quiet_mode; shift;fi
URL="$1"
[ "$URL" ] || URL="http://www.bing.com/search?q=60s+news&first=1"
  

Sleep_To_Open_URL=$2; [ "$Sleep_To_Open_URL" ] || Sleep_To_Open_URL=5 ;
Sleep_To_Execute_Script=$3; [ "$Sleep_To_Execute_Script" ]||Sleep_To_Execute_Script=$Sleep_To_Open_URL;


PORT=$(($RANDOM%2000+2000));while nc -z 127.0.0.1 $PORT; do PORT=$(($PORT+1));done;


PROFILEDIR=$(mktemp -d)
echo "user_pref(\"marionette.port\", $PORT); " >> $PROFILEDIR/prefs.js
echo "user_pref(\"marionette.port\", $PORT); " >> $PROFILEDIR/user.js

firefox --marionette -no-remote $quiet_mode -profile $PROFILEDIR 2>/dev/null &

while ! sleep 0.2|nc 127.0.0.1 $PORT | grep -i marionetteProtocol ; do sleep 1;done

(
  echo -n '54:[0,1,"WebDriver:NewSession",{"browserName":"firefox"}]' 
  sleep 0.1
  OpenURL  "$URL"  $PORT
  sleep $Sleep_To_Open_URL
  echo -e \\n\\n==============================\\n\\n  >&2
  ExecuteScript  "return document.body.outerHTML;"  $PORT
  sleep $Sleep_To_Execute_Script

  SendFirefoxMarionetteCmd "WebDriver:CloseWindow"  ""  $PORT  
  SendFirefoxMarionetteCmd  "Marionette:Quit", "\"flags\":[\"eForceQuit\"]"   $PORT 

) | nc 127.0.0.1 $PORT


ps -AF | grep firefox |grep -e "-profile $PROFILEDIR" | awk '{print $2}' | xargs -t kill

rm -rf "$PROFILEDIR"

exit





======================================================
      Documment of Marionette Mode


54:[0,1,"WebDriver:NewSession",{"browserName":"firefox"}]
83:[0,2,"WebDriver:Navigate",{"url":"https://www.bing.com/search?q=firefox+headless"}]
86:[0,3,"WebDriver:ExecuteScript",{"args":[],"script":"return document.head.outerHTML;"}]
86:[0,4,"WebDriver:ExecuteScript",{"args":[],"script":"return document.body.outerHTML;"}]
32:[0,5,"WebDriver:CloseWindow",{}]
48:[0,6,"Marionette:Quit",{"flags":["eForceQuit"]}]
===============================================================
./prefs.js:user_pref("marionette.enabled", true);
./prefs.js:user_pref("marionette.port", 5555);

 firefox --marionette --headless 

NEW_SESSION_CMD='54:[0,1,"WebDriver:NewSession",{"browserName":"firefox"}]'
echo "$NEW_SESSION_CMD" | nc 127.0.0.1 5555 









=======================================================

      Documment of geckodriver



POST /session
  --data {"capabilities": {"firstMatch": [{}], "alwaysMatch": {"acceptInsecureCerts": true, "moz:firefoxOptions": {"args": ["--headless", "--disable-gpu"]}, "browserName": "firefox"}}, "desiredCapabilities": {"acceptInsecureCerts": true, "moz:firefoxOptions": {"args": ["--headless", "--disable-gpu"]}, "browserName": "firefox", "marionette": true}}
  result: {"value":{"sessionId":"e57b11b0-7354-4147-8f9e-000aac789d6a","capabilities":.....
POST /session/e57b11b0-7354-4147-8f9e-000aac789d6a/url HTTP/1.
1
   --data {"url": "https://bing.com"}
POST /session/e57b11b0-7354-4147-8f9e-000aac789d6a/element HTTP/1.1
   --data {"value": "body", "using": "css selector"}
  result:{"value":{"element-6066-11e4-a52e-4f735466cecf":"656e1678-3d9d-4f50-8011-6f8d52c6c9a2"}}
POST /session/be40cf2d-41b7-411f-a9d7-e7d6910e9b38/execute/sync HTTP/1.1
  --data {"script": "return document.title;", "args": []}
GET /session/e57b11b0-7354-4147-8f9e-000aac789d6a/screenshot HTTP/1.1
GET /session/e57b11b0-7354-4147-8f9e-000aac789d6a/element/656e1678-3d9d-4f50-8011-6f8d52c6c9a2/property/outerHTML HTTP/1.1
POST /session/session/$SessionID/element/$ElementID/value ##send_keys
  --data {"value": ["/", "t", "m", "p", ], "id": "69cb1555-5923-40ef-9f47-0c21edb46e6a", "text": "/tmp"}
==============================================


RESULT=$( wget -O- -S 127.0.0.1:4444/session  --header="Content-Type: application/json;charset=UTF-8"  --post-data='{"capabilities": {"firstMatch": [{}], "alwaysMatch": {"acceptInsecureCerts": true, "moz:firefoxOptions": {"args": ["--headless", "--disable-gpu"]}, "browserName": "firefox"}}, "desiredCapabilities": {"acceptInsecureCerts": true, "moz:firefoxOptions": {"args": ["--headless", "--disable-gpu"]}, "browserName": "firefox", "marionette": true}}' )

SessionID=$( echo $RESULT | sed "s/[{,}]/\n/g" | grep ^\"sessionId\": | awk -F\" '{print $4}' )

wget -O- -S 127.0.0.1:4444/session/$SessionID/url  --header="Content-Type: application/json;charset=UTF-8"  --post-data='{"url": "https://bing.com"}'

Element_RESULT=$( wget -O- 127.0.0.1:4444/session/$SessionID/element  --header="Content-Type: application/json;charset=UTF-8"  --post-data='{"value": "body", "using": "css selector"}' )

ElementID=$( echo $Element_RESULT | awk -F\" '{print $6}' )

wget -O- 127.0.0.1:4444/session/$SessionID/element/$ElementID/property/outerHTML
wget -O- 127.0.0.1:4444/session/$SessionID/element/$ElementID/screenshot

wget -O- 127.0.0.1:4444/session/$SessionID/execute/sync --header="Content-Type: application/json;charset=UTF-8"  --post-data='{"script": "return document.body.outerHTML;", "args": []}'

===================================================



