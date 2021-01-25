local lfs = require "lfs"
local utils = require "utils"

assert(arg[1])

local directory = "."
local build_project = arg[1]

-- iterate over modules and get all .java files
local main_class = arg[2]

-- tests the functions above
local file = build_project .. '/.idea/modules.xml'
local lines = utils.lines_from(file)

local module_names = utils.module_names(lines)

local modules = {}

-- determine dependancy for all modules
for _, mod_name in pairs(module_names) do
  -- get iml file
  local iml_lines = utils.lines_from(directory .. "/" .. mod_name .. "/" .. mod_name .. ".iml")

  -- find all dependant modules
  local dep_mods = utils.dependant_module_names(iml_lines)

  modules[mod_name] = {}

  for i,v in ipairs(dep_mods) do
    modules[mod_name][#modules[mod_name] + 1] = v
  end

end

local depth_grouped_modules = {}

-- now work out "depth" of each modules to determine module compile order
for module_name, deps in pairs(modules) do
  local depth = utils.calc_depth(modules, module_name, 1)

  if not depth_grouped_modules[depth] then
    depth_grouped_modules[depth] = {}
  end

  depth_grouped_modules[depth][#depth_grouped_modules[depth] + 1] = module_name
end

-- create date time index for files
local date = os.date("%Y_%m_%d")
local time = os.time("%H_%M_%S")

local date_time_index = date .. "_" .. time;

-- cleanup
utils.deletedir('lib')
lfs.mkdir("lib")
utils.deletedir("out")
lfs.mkdir("out")

-- build
for depth, module_names_in_depth in pairs(depth_grouped_modules) do

  for _, mod_name in pairs(module_names_in_depth) do

  	print("----- Building " .. mod_name)

    utils.deletedir(mod_name .. "/out")

  	lfs.mkdir(mod_name .. "/out")

  	local files = {}

  	files = utils.get_file_list(directory .. "/" .. mod_name .. "/src", files)

    -- compile to local place for jar creation
  	local compile_string = "javac --module-path lib;third_party -d " .. mod_name .. "/out "

    -- create file with list of sources to get around cmd character limit
    local sources_file = io.open("sources.txt", w)
  	for index, file in pairs(files) do

      -- check its a jar file
      if utils.ends_with(file, ".java") then
    		io.write(string.sub(file, 3) .. " ")
      end

  	end
    io.close(sources_file)
  		
    -- compile
    local t = os.execute(compile_string .. " @sources.txt")

    --now copy over none java files
    for not index, file in pairs(files) do

      if not utils.ends_with(file, ".java") then

        local start_file = file:sub(3)
        local end_file = mod_name .. "/out/" .. string.sub(file, string.len("/" .. directory .. "/" .. mod_name .. "/src/"))

        -- mkdir just incase it doesnt exist
        os.execute("mkdir " .. utils.getParentPath(end_file:gsub("/", "\\\\")))

        os.execute("copy " .. start_file:gsub("/", "\\\\") .. " " .. end_file:gsub("/", "\\\\"))

      end

    end

  	-- make jar
  	local t = os.execute("jar -c -f lib/" .. mod_name .. ".jar -C " .. mod_name .. "/out .")

  end
end

-- run main
print("----- Running " .. main_class)
utils.deletedir("out")
lfs.mkdir("out")

-- command to run if need be
if main_class then
  local t = os.execute("java --module-path lib;third_party -m " .. main_class)
end

local test_result = {}

-- run tests
for depth, module_names_in_depth in pairs(depth_grouped_modules) do

  for _, mod_name in pairs(module_names_in_depth) do

    print("----- Building " .. mod_name .. " tests")

    local test_files = {}

    test_files = utils.get_file_list(directory .. "/" .. mod_name .. "/src", test_files)
    test_files = utils.get_file_list(directory .. "/" .. mod_name .. "/test", test_files)

    -- get all test classes (with full path)
    test_classes = {}
    test_classes = utils.get_file_list(directory .. "/" .. mod_name .. "/test", test_classes)

    -- create to gloabl place for testing
    local test_compile_string = "javac --module-path lib;third_party -d out -classpath third_party;test_lib/junit-4.12.jar "

    -- now add-reads for module and all dependant modules because java 9
    test_compile_string = test_compile_string .. "--add-reads " .. mod_name .. "=ALL-UNNAMED "
    for _, dep_names in pairs(modules[mod_name]) do
      test_compile_string = test_compile_string .. "--add-reads " .. dep_names .. "=ALL-UNNAMED --add-modules " .. dep_names .. " "
    end

    -- create file with list of sources to get around cmd character limit
    local sources_file = io.open("sources.txt", w)
    for index, file in pairs(test_files) do

      -- check its a jar file
      if utils.ends_with(file, ".java") then
        io.write(string.sub(file, 3) .. " ")
      end

    end
    io.close(test_compile_string .. " @sources.txt")
      
    -- compile
    local t = os.execute(compile_string .. " @sources.txt")

    --now copy over none java files
    for not index, file in pairs(test_files) do


      if not utils.ends_with(file, ".java") then

        local start_file = file:sub(3)
        local end_file = "out/" .. string.sub(file, string.len("/" .. directory .. "/" .. mod_name .. "/src/"))

        -- mkdir just incase it doesnt exist
        os.execute("mkdir " .. utils.getParentPath(end_file:gsub("/", "\\\\")))

        os.execute("copy " .. start_file:gsub("/", "\\\\") .. " " .. end_file:gsub("/", "\\\\"))

      end

    end
    
    -- compile test
    local t = os.execute(test_compile_string)

    test_result[mod_name] = {}

    -- run tests
    for k,v in pairs(test_classes) do
      local test_class = v:gsub(directory .. "/" .. mod_name .. "/test/", ""):gsub("/", "%."):gsub(".java", "")
      local handle = io.popen("java -cp \"out;third_party;test_lib/hamcrest-2.2.jar;test_lib/junit-4.12.jar\" -p third_party;lib org.junit.runner.JUnitCore " .. test_class)
      local result = handle:read("*a")
      handle:close()
      test_result[mod_name][test_class] = result
    end

  end

end

os.remove("sources.txt")

local test_output = io.open("test_outputs/" .. date_time_index .. "_test_output.html", "w")
io.output(test_output)

io.write("<h1>Test Results at " .. os.date("%Y/%m/%d %X") .. "</h1>")

for mod_name, class_tests in pairs(test_result) do

  local color = "green"
  local empty = true

  -- check if it has_passed
  for class_name, test_result_string in pairs(class_tests) do

    if test_result_string ~= "" then
      empty = false
    end

    if string.find(test_result_string, "FAILURES!!!") then
      color = "red"
      break
    end

  end

  if empty then
    color = "yellow"
  end

  io.write("<details><summary><span style=\"color:" .. color .. "\">" .. mod_name .. "</span></summary>")

  for class_name, test_result in pairs(class_tests) do

    local_color = "green"
    if string.find(test_result, "FAILURES!!!") then
      local_color = "red"
    end
    
    io.write("<h3><span style=\"color:" .. local_color .. "\">" .. class_name .. "</span></h3>")

    io.write("<p>" .. test_result .. "</p>")

  end

  io.write("</details>")

end

io.close(test_output)

test_output_files = utils.get_test_output_list("test_outputs/")

local index = io.open("test_outputs/index.html", "w")

io.output(index)

local begining = [[


<!DOCTYPE html>
<html lang="en">
<head>
<meta charset="utf-8" />
<title>CAT CI SERVER!</title>

<link rel="stylesheet" href="main.css"/>

</head>

<script>
function RunExe(){
    var shell = new ActiveXObject("WScript.Shell");
    var path = '"file:///run.bat"';
    shell.run(path,1,false);
}
</script>

<body id="index" class="home">

<header id="banner" class="body">
  <h1 id="demo" >CAT CI SERVER</h1>

  <nav><ul>
    <li class="active"><a href="index.html">Overview</a></li>
    <li><a href="proj_info.html">Project Information</a></li>
    <li><a href="help.html">Help</a></li>
  </ul></nav>

</header>

<aside id="featured" class="body">
  <article>

    <hgroup>
      <input id="clickMe" type="button" value="clickme" onclick="RunExe()" />
    </hgroup>

  </article>
</aside>

<section id="extras" class="body">
  <div class="blogroll">
    <h2>Test Cases</h2>
    <ul>

    ]]


local end_file = [[
    </ul>
  </div>

</section>

<footer id="contentinfo" class="body">
  <address id="about" class="vcard body">

    <span class="primary">
      <strong>CAT CI SERVER</strong>
    </span>

  </address>
</footer>

</body>
</html>

]]

io.write(begining)

io.write("<h1>Test results index page</h1><ol>\n")

for i,test_output_file_names in ipairs(utils.reverse_list(test_output_files)) do

  local path = lfs.currentdir() .. "/test_outputs/" .. test_output_file_names

  local dot_col = "red_dot"

  if utils.has_passed(utils.lines_from("test_outputs/" .. test_output_file_names)) then
    dot_col = "green_dot"
  end

  io.write("<li><a href=\"" .. test_output_file_names .. "\" rel=\"external\"><span class=\"" .. dot_col .. "\"></span>  " .. test_output_file_names:gsub(".html", "") .. "</a></li>\n")

end


io.write(end_file)

io.close(index)

utils.deletedir('out')