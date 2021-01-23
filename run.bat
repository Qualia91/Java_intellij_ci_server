
hg clone ../third_party
hg clone ../com.hello
hg clone ../com.hello_client

lua java_build_tool.lua "com.hello_client/com.hello_client.HelloWorldClient"

rmdir third_party /q /s
rmdir com.hello /q /s
rmdir com.hello_client /q /s

exit