local home = os.getenv("HOME")
local bundles = {}

-- java-test
local java_test_path = os.getenv("MASON") .. "/packages/java-test"
local java_test_bundle = vim.split(vim.fn.glob(java_test_path .. "/extension/server/*.jar"), "\n")
if java_test_bundle[1] ~= "" then
  vim.list_extend(bundles, java_test_bundle)
end

-- java-debug-adapter
local java_debug_path = os.getenv("MASON") .. "/packages/java-debug-adapter"
local java_debug_bundle =
  vim.split(vim.fn.glob(java_debug_path .. "/extension/server/com.microsoft.java.debug.plugin-*.jar"), "\n")
if java_debug_bundle[1] ~= "" then
  vim.list_extend(bundles, java_debug_bundle)
end

-- spring boot extensions
vim.list_extend(bundles, require("spring_boot").java_extensions())

-- dependency explorer (optional)
local java_dependency_bundle = vim.split(
  vim.fn.glob(
    home .. "/projects/vscode-java-dependency/jdtls.ext/com.microsoft.jdtls.ext.core/target/com.microsoft.jdtls.ext.core-*.jar"
  ),
  "\n"
)
if java_dependency_bundle[1] ~= "" then
  vim.list_extend(bundles, java_dependency_bundle)
end

-- project root (gradle only)
local root_dir = vim.fs.dirname(vim.fs.find({ "gradlew" })[1])
local workspace_folder = home .. "/.local/share/eclipse/" .. vim.fn.fnamemodify(root_dir, ":p:h:t")

local extendedClientCapabilities = require("jdtls").extendedClientCapabilities
extendedClientCapabilities.resolveAdditionalTextEditsSupport = true

local mason_path = vim.fn.stdpath("data") .. "/mason"
local jdtls_path = mason_path .. "/packages/jdtls"
local jar = vim.fn.glob(jdtls_path .. "/plugins/org.eclipse.equinox.launcher.jar")

local lombok = home .. "/.local/share/nvim/mason/packages/lombok-nightly/lombok.jar"

-- jdtls config
local config = {
  settings = {
    java = {
      eclipse = { downloadSources = true },
      maven = { downloadSources = false }, -- disable Maven
      configuration = { updateBuildConfiguration = "interactive" },
      references = { includeDecompiledSources = true },
      implementationsCodeLens = { enabled = true },
      referenceCodeLens = { enabled = true },
      inlayHints = { parameterNames = { enabled = "all" } },
      signatureHelp = { enabled = true, description = { enabled = true } },
      sources = { organizeImports = { starThreshold = 9999, staticStarThreshold = 9999 } },
    },
  },
  flags = { allow_incremental_sync = true },
  capabilities = require("blink.cmp").get_lsp_capabilities(),
  on_attach = function(client, bufnr)
    require("jdtls").setup_dap({ hotcodereplace = "auto" })
    require("jg.custom.lsp-utils").attach_lsp_config(client, bufnr)
    require("jdtls.dap").setup_dap_main_class_configs()

    vim.api.nvim_create_autocmd("BufWritePost", {
      pattern = { "*.java" },
      callback = function()
        local _, _ = pcall(vim.lsp.codelens.refresh)
      end,
    })
  end,
  cmd = {
    "java",
    "-Declipse.application=org.eclipse.jdt.ls.core.id1",
    "-Dosgi.bundles.defaultStartLevel=4",
    "-Declipse.product=org.eclipse.jdt.ls.core.product",
    "-Dlog.protocol=true",
    "-Dlog.level=ALL",
    "-Xms1G",
    "--add-modules=ALL-SYSTEM",
    "--add-opens", "java.base/java.util=ALL-UNNAMED",
    "--add-opens", "java.base/java.lang=ALL-UNNAMED",
    "-javaagent:" .. lombok,
    "-jar", jar,
    "-configuration", home .. "/.local/share/nvim/mason/packages/jdtls/config_mac_arm",
    "-data", workspace_folder,
  },
  root_dir = root_dir,
  init_options = {
    bundles = bundles,
    extendedClientCapabilities = extendedClientCapabilities,
  },
}

require("jdtls").start_or_attach(config)

--------------------------------------------------------------------------------
-- GRADLE HELPERS

local function get_test_runner(test_name, debug)
  if debug then
    -- debug with Gradle
    return "./gradlew test --debug-jvm --tests \"" .. test_name .. "\""
  end
  return "./gradlew test --tests \"" .. test_name .. "\""
end

local function run_java_test_method(debug)
  local utils = require("jg.core.utils")
  local method_name = utils.get_current_full_method_name("\\#")
  vim.cmd("term " .. get_test_runner(method_name, debug))
end

local function run_java_test_class(debug)
  local utils = require("jg.core.utils")
  local class_name = utils.get_current_full_class_name()
  vim.cmd("term " .. get_test_runner(class_name, debug))
end

local function get_spring_boot_runner(profile, debug)
  local debug_param = ""
  if debug then
    debug_param = " --debug-jvm "
  end

  local profile_param = ""
  if profile then
    profile_param = " -Dspring.profiles.active=" .. profile .. " "
  end

  return "./gradlew bootRun " .. profile_param .. debug_param
end

local function run_spring_boot(debug)
  vim.cmd("15sp|term " .. get_spring_boot_runner(nil, debug))
end

-- Keymaps
vim.keymap.set("n", "<F7>", function() run_java_test_method() end)
vim.keymap.set("n", "<F8>", function() run_java_test_method(true) end)
vim.keymap.set("n", "<leader>Tc", function() run_java_test_class() end)
vim.keymap.set("n", "<leader>TC", function() run_java_test_class(true) end)
vim.keymap.set("n", "<F9>", function() run_spring_boot() end)
vim.keymap.set("n", "<F10>", function() run_spring_boot(true) end)
