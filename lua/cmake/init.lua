local dap = require('dap')
local utils = require('cmake.utils')
local cmake = {}

function cmake.configure(...)
  if vim.fn.filereadable('CMakeLists.txt') ~= 1 then
    print('Unable to find CMakeLists.txt')
    return
  end

  local parameters = utils.get_parameters()
  local build_dir = utils.get_build_dir(parameters)
  local command = table.concat({'cmake', vim.g.cmake_configure_arguments, table.concat({...}, ' '), '-D', 'CMAKE_BUILD_TYPE=' .. parameters['buildType'], '-B', build_dir}, ' ')
  vim.fn.mkdir(build_dir, 'p')
  utils.make_query_files(build_dir)
  utils.asyncrun_callback('require(\'cmake.utils\').copy_compile_commands()')
  vim.fn['asyncrun#run']('', vim.g.cmake_asyncrun_options, command)
end

function cmake.build(...)
  local parameters = utils.get_parameters()
  local target_name = parameters['currentTarget']
  if not target_name or #target_name == 0 then
    print('You need to select target first')
    return
  end

  local command = table.concat({'cmake', '--build', utils.get_build_dir(parameters), '--target', target_name, ...}, ' ')
  utils.autoclose_quickfix(vim.g.cmake_asyncrun_options)
  utils.asyncrun_callback('require(\'cmake.utils\').copy_compile_commands()')
  vim.fn['asyncrun#run']('', vim.g.cmake_asyncrun_options, command)
end

function cmake.build_all(...)
  local command = table.concat({'cmake', '--build', utils.get_build_dir(), ...}, ' ')
  utils.autoclose_quickfix(vim.g.cmake_asyncrun_options)
  utils.asyncrun_callback('require(\'cmake.utils\').copy_compile_commands()')
  vim.fn['asyncrun#run']('', vim.g.cmake_asyncrun_options, command)
end

function cmake.run(...)
  local target_dir, target, arguments = utils.get_current_target(utils.get_parameters())
  if not target then
    return
  end

  local command = table.concat({target, arguments, ...}, ' ')
  utils.autoclose_quickfix(vim.g.cmake_target_asyncrun_options)
  vim.fn['asyncrun#run']('', vim.fn.extend(vim.g.cmake_target_asyncrun_options, {cwd = target_dir}), command)
end

function cmake.debug(...)
  local parameters = utils.get_parameters()
  if not utils.check_debugging_build_type(parameters) then
    return
  end

  local target_dir, target, arguments = utils.get_current_target(parameters)
  if not target then
    return
  end

  -- Split on spaces unless in quotes
  local splitted_args = vim.fn.split(arguments, "[^\\s\"']+|\"([^\"]*)\"|'([^']*)'")
  table.insert(splitted_args, {...})

  vim.cmd('cclose')
  local config = {
    type = 'cpp',
    name = 'Debug CMake target',
    request = 'launch',
    program = target,
    args = splitted_args,
    cwd = target_dir,
  }
  dap.run(config)
  dap.repl.open()
end

function cmake.clean(...)
  local command = table.concat({'cmake', table.concat({...}, ' '), '--build', utils.get_build_dir(), '--target', 'clean'}, ' ')
  utils.autoclose_quickfix(vim.g.cmake_asyncrun_options)
  utils.asyncrun_callback('require(\'cmake.utils\').copy_compile_commands()')
  vim.fn['asyncrun#run']('', vim.g.cmake_asyncrun_options, command)
end

function cmake.build_and_run(...)
  local parameters = utils.get_parameters()
  if not utils.get_current_executable_info(parameters, utils.get_build_dir(parameters)) then
    return
  end

  utils.asyncrun_callback('require(\'cmake\').run()')
  cmake.build(...)
end

function cmake.build_and_debug(...)
  local parameters = utils.get_parameters()
  if not utils.get_current_executable_info(parameters, utils.get_build_dir(parameters)) then
    return
  end

  if not utils.check_debugging_build_type(parameters) then
    return
  end

  utils.asyncrun_callback('require(\'cmake\').debug()')
  cmake.build(...)
end

function cmake.set_target_arguments()
  local parameters = utils.get_parameters()
  local current_target = utils.get_current_executable_info(parameters, utils.get_build_dir(parameters))
  if not current_target then
    return
  end

  local current_target_name = current_target['name']
  parameters['arguments'][current_target_name] = vim.fn.input(current_target_name .. ' arguments: ', vim.fn.get(parameters['arguments'], current_target_name), 'file')
  utils.set_parameters(parameters)
end

function cmake.clear_cache()
  local cache_file = utils.get_build_dir() .. 'CMakeCache.txt'
  if vim.fn.filereadable(cache_file) ~= 1 then
    print('Cache file ' .. cache_file .. ' does not exists')
    return
  end

  if vim.fn.delete(cache_file) == 0 then
    print('Cache file '  .. cache_file .. ' was deleted successfully')
  else
    print('Unable to delete cache file '  .. cache_file)
  end
end

function cmake.open_build_dir()
  local program = vim.fn.has('win32') == 1 and 'start ' or 'xdg-open '
  vim.fn.system(program .. utils.get_build_dir())
end

return cmake
