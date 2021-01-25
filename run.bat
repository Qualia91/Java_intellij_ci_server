pushd %~dp0

hg clone D:/Software/Programming/projects/Java/commandLineBuildTest/third_party > nul 2>&1
hg clone D:/Software/Programming/projects/Java/commandLineBuildTest/com.hello > nul 2>&1
hg clone D:/Software/Programming/projects/Java/commandLineBuildTest/com.hello_client > nul 2>&1

pushd %~dp0

lua java_build_tool.lua "com.hello_client/com.hello_client.HelloWorldClient"

rmdir third_party /q /s
rmdir com.hello /q /s
rmdir com.hello_client /q /s
