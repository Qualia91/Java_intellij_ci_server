local lfs = require "lfs"
local utils = require "utils"


local directory = "."
local build_project = "com.hello"

assert(arg[0])

-- iterate over modules and get all .java files
local main_class = arg[0] -- eg "com.hello_client/com.hello_client.HelloWorldClient"

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
local date = os.date("%Y/%m/%d"):gsub("/", "_")
local time = os.time()

local date_time_index = time .. "_" .. date;

-- cleanup
utils.deletedir('lib')
lfs.mkdir("lib")
utils.deletedir("out")

-- build
for depth, module_names_in_depth in ipairs(depth_grouped_modules) do

  for _, mod_name in pairs(module_names_in_depth) do

  	print("----- Building " .. mod_name)

    utils.deletedir(mod_name .. "/out")

  	lfs.mkdir(mod_name .. "/out")

  	local files = {}

  	files = utils.get_file_list(directory .. "/" .. mod_name, files, false)

    -- compile to local place for jar creation
  	local compile_string = "javac --module-path lib;third_party -d " .. mod_name .. "/out "

  	for index, file in pairs(files) do

  		compile_string = compile_string .. string.sub(file, 3) .. " "

  	end
  		
    -- compile
    local t = os.execute(compile_string)

  	-- make jar
  	local t = os.execute("jar -c -f lib/" .. mod_name .. ".jar -C " .. mod_name .. "/out .")

  end
end

-- run main
print("----- Running " .. main_class)
utils.deletedir("out")
lfs.mkdir("out")

-- command to run if need be
-- local t = os.execute("java --module-path lib;third_party -m " .. main_class)

local test_result = {}

-- run tests
for depth, module_names_in_depth in ipairs(depth_grouped_modules) do

  for _, mod_name in pairs(module_names_in_depth) do

    print("----- Building " .. mod_name .. " tests")

    local test_files = {}

    test_files = utils.get_file_list(directory .. "/" .. mod_name, test_files, true)

    -- get all test classes (with full path)
    test_classes = {}
    test_classes = utils.get_file_list(directory .. "/" .. mod_name .. "/test", test_classes, true)

    -- create to gloabl place for testing
    local test_compile_string = "javac --module-path lib;third_party -d out -classpath third_party;test_lib/junit-4.12.jar "

    -- now add-reads for module and all dependant modules because java 9
    test_compile_string = test_compile_string .. "--add-reads " .. mod_name .. "=ALL-UNNAMED "
    for _, dep_names in pairs(modules[mod_name]) do
      test_compile_string = test_compile_string .. "--add-reads " .. dep_names .. "=ALL-UNNAMED --add-modules " .. dep_names .. " "
    end

    for index, file in pairs(test_files) do

      test_compile_string = test_compile_string .. string.sub(file, 3) .. " "

    end
    
    -- compile test
    local t = os.execute(test_compile_string)

    test_result[mod_name] = {}

    -- run tests
    for k,v in pairs(test_classes) do
      local test_class = v:gsub(directory .. "/" .. mod_name .. "/test/", ""):gsub("/", "%."):gsub(".java", "")
      local handle = io.popen("java -cp \"out;third_party;test_lib/hamcrest-2.2.jar;test_lib/junit-4.12.jar\" org.junit.runner.JUnitCore " .. test_class)
      local result = handle:read("*a")
      handle:close()
      test_result[mod_name][test_class] = result
    end

  end

end

local test_output = io.open("test_outputs/" .. date_time_index .. "_test_output.html", "w")
io.output(test_output)

io.write("<h1>Test Results at " .. os.date("%Y/%m/%d %X") .. "</h1>")

for mod_name, class_tests in pairs(test_result) do

  io.write("<details><summary>" .. mod_name .. "</summary>")

  for class_name, test_result in pairs(class_tests) do
    
    io.write("<h3>" .. class_name .. "</h3>")

    io.write("<p>" .. test_result .. "</p>")

  end

  io.write("</details>")

end

io.close(test_output)

test_output_files = utils.get_test_output_list("test_outputs/")

local index = io.open("test_outputs/index.html", "w")

io.output(index)

local html_header = [[

<!DOCTYPE html>
<html>
<head>
<link rel="stylesheet" href="style.css">
</head>
<body>


</body>
</html>

]]

io.write(html_header)

io.write("<h1>Test results index page</h1><ol>\n")

for i,test_output_file_names in ipairs(utils.reverse_list(test_output_files)) do

  local path = lfs.currentdir() .. "/test_outputs/" .. test_output_file_names

  local dot_col = "red_dot"

  if utils.has_passed(utils.lines_from("test_outputs/" .. test_output_file_names)) then
    dot_col = "green_dot"
  end

  io.write("<li><a href=\"file:///" .. path:gsub("/" , "\\") .. "\">" ..  test_output_file_names .. "</a><span class=\"" .. dot_col .. "\"></span>\n</li>\n")

end

io.write("</ol>\n")
io.write("</body>\n")
io.write("</html>\n")

io.close(index)

utils.deletedir('out')