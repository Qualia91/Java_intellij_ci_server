local lfs = require"lfs"

local utils = {}


function utils.starts_with(str, start)
   return str:sub(1, #start) == start
end

function utils.ends_with(str, ending)
   return ending == "" or str:sub(-#ending) == ending
end

function utils.deletedir(dir)
    for file in lfs.dir(dir) do
        local file_path = dir..'/'..file
        if file ~= "." and file ~= ".." then
            if lfs.attributes(file_path, 'mode') == 'file' then
                os.remove(file_path)
            elseif lfs.attributes(file_path, 'mode') == 'directory' then
                utils.deletedir(file_path)
            end
        end
    end
    lfs.rmdir(dir)
end

function utils.add_to_file_list(dir, file, files)
  if lfs.attributes(dir .. "/" .. file,"mode") == "file" and not utils.ends_with(file, ".iml") and not utils.starts_with(file, ".") then 
    files[#files + 1] = dir .. "/" .. file
  elseif lfs.attributes(dir .. "/" .. file,"mode") == "directory" then 
    files = utils.get_file_list(dir .. "/" .. file, files)
  end
  return files
end 

function utils.get_file_list(dir, files) 

	for file in lfs.dir(dir) do
    if file ~= ".hg" and file ~= "." and file ~= ".." and file ~= "out" and file ~= ".idea" then 
      files = utils.add_to_file_list(dir, file, files)
		end	
	end

	return files

end

function utils.get_test_output_list(dir) 

  local files = {}

  for file in lfs.dir(dir) do
      if file ~= "." and file ~= ".." and file ~= "index.html" and file ~= "help.html" and file ~= "proj_info.html" and utils.ends_with(file, ".html") then 
        files[#files + 1] = file
    end 
  end

  return files

end

-- get modules from <BUILD_PORJ>/.idea/modules.xml
-- see if the file exists
function utils.file_exists(file)
  local f = io.open(file, "rb")
  if f then f:close() end
  return f ~= nil
end

-- get all lines from a file, returns an empty 
-- list/table if the file does not exist
function utils.lines_from(file)
  if not utils.file_exists(file) then return {} end
  lines = {}
  for line in io.lines(file) do 
    lines[#lines + 1] = line
  end
  return lines
end

-- get module names
function utils.module_names(lines)
  local module_names = {}
  local module_reader = "PROJECT_DIR$/.-\" filepath="
  for _,v in pairs(lines) do
      if string.find(v, "<module fileurl") then
        local part = string.sub(v, string.find(v, module_reader))
        local remove_front = string.gsub(part, "PROJECT_DIR$/", "")
        local remove_end = string.gsub(remove_front, "\" filepath=", "")
        local module_name_and_path = remove_end:gsub("%.%./", "")
        local iml_file_split = utils.split(module_name_and_path, "/")
        local iml_file =  iml_file_split[#iml_file_split]
        local module_name = iml_file:gsub("%.iml", "")
        module_names[#module_names + 1] = module_name
    end
  end
  return module_names
end

-- get module names
function utils.dependant_module_names(lines)
  local module_names = {}
  local module_reader = "module%-name=\".-\""
  for _,v in pairs(lines) do
    if string.find(v, "module%-name") then
      local part = string.sub(v, string.find(v, module_reader))
      local remove_front = string.gsub(part, "module%-name=\"", "")
      local remove_end = string.gsub(remove_front, "\"", "")
      module_names[#module_names + 1] = remove_end
    end
  end
  return module_names
end

-- did test pass, takes in lines from test output
function utils.has_passed(lines)
  for _,v in pairs(lines) do

    if string.find(v, "FAILURES!!!") then
      return false
    end
  end
  return true
end

function utils.split(inputstr, sep)
        if sep == nil then
                sep = "%s"
        end
        local t={}
        for str in string.gmatch(inputstr, "([^"..sep.."]+)") do
                table.insert(t, str)
        end
        return t
end

function utils.calc_depth(modules, module_name, depth)

  -- get deps of current module
  local mod_deps = modules[module_name]

  if #mod_deps > 0 then

    depth = depth + 1

  end

  -- iterate
  for i,dep_name in ipairs(mod_deps) do
    local new_depth = utils.calc_depth(modules, dep_name, depth)
    if new_depth > depth then
      depth = new_depth
    end
  end

  return depth

end

function utils.reverse_list(list)
  rev = {}
  for i=#list, 1, -1 do
    rev[#rev+1] = list[i]
  end
  return rev
end

function utils.get_parent_path(path) 
  local function getParentPath(_path)
    pattern1 = "^(.+)//"
    pattern2 = "^(.+)\\"

    if (string.match(path,pattern1) == nil) then
        return string.match(path,pattern2)
    else
        return string.match(path,pattern1)
    end
  end
end

return utils