---@diagnostic disable: inject-field, redefined-local
local GLOBALS = require("kulala.globals")
local CONFIG = require("kulala.config")
local DB = require("kulala.db")
local kulala = require("kulala")

local h = require("test_helper.ui")
local s = require("test_helper.stubs")

local assert = require("luassert")
assert.is_same = assert.is_same

describe("requests", function()
  describe("show output of requests", function()
    local curl, jobstart, system, notify, dynamic_vars
    local result, expected, ui_buf

    before_each(function()
      h.delete_all_bufs()

      notify = s.Notify.stub()
      dynamic_vars = s.Dynamic_vars.stub()

      curl = s.Curl.stub({
        ["*"] = {
          stats = h.load_fixture("fixtures/request_1_stats.txt"),
          headers = h.load_fixture("fixtures/request_2_headers.txt"),
        },
        ["http://localhost:3001/request_1"] = {
          body = h.load_fixture("fixtures/request_1_body.txt"),
          errors = h.load_fixture("fixtures/request_1_errors.txt"),
        },
        ["http://localhost:3001/request_2"] = {
          body = h.load_fixture("fixtures/request_2_body.txt"),
          errors = h.load_fixture("fixtures/request_2_errors.txt"),
        },
      })

      jobstart = s.Jobstart.stub({ "curl" }, {
        on_call = function(jobstart)
          curl.request(jobstart)
        end,
        on_exit = 0,
      })

      system = s.System.stub({ "curl" }, {
        on_call = function(system)
          curl.request(system)
        end,
      })
    end)

    after_each(function()
      h.delete_all_bufs()
      curl.reset()
      jobstart.reset()
      system.reset()
      notify.reset()
      dynamic_vars.reset()
    end)

    it("shows last request output in body_headers mode for run_all", function()
      local lines = h.to_table(
        [[
        GET http://localhost:3001/request_1

        ###

        GET http://localhost:3001/request_2
      ]],
        true
      )

      h.create_buf(lines, "test.http")
      CONFIG.options.default_view = "headers_body"
      CONFIG.options.display_mode = "float"

      kulala.run_all()

      system:wait(3000, function()
        ui_buf = vim.fn.bufnr(GLOBALS.UI_ID)
        return curl.requests_no == 2 and ui_buf ~= -1
      end)

      expected = h.load_fixture("fixtures/request_2_headers_body.txt")
      result = h.get_buf_lines(ui_buf):to_string()

      assert.is_same(2, curl.requests_no)
      assert.is_same(expected, result)
    end)

    it("shows request output in verbose mode for run_one", function()
      local lines = h.to_table(
        [[
        GET http://localhost:3001/request_1
      ]],
        true
      )

      h.create_buf(lines, "test.http")
      CONFIG.options.default_view = "verbose"
      CONFIG.options.display_mode = "float"

      kulala.run()
      jobstart.wait(3000, function()
        ui_buf = vim.fn.bufnr(GLOBALS.UI_ID)
        return ui_buf > 0
      end)

      result = h.get_buf_lines(ui_buf):to_string()
      expected = h.load_fixture("fixtures/request_1_verbose.txt")

      assert.is_same(expected, result)
    end)

    it("shows last request output in verbose mode for run_all", function()
      local lines = h.to_table(
        [[
        GET http://localhost:3001/request_1

        ###

        GET http://localhost:3001/request_2
      ]],
        true
      )

      h.create_buf(lines, "test.http")
      CONFIG.options.default_view = "verbose"
      CONFIG.options.display_mode = "float"

      kulala.run_all()

      system:wait(3000, function()
        ui_buf = vim.fn.bufnr(GLOBALS.UI_ID)
        return curl.requests_no == 2 and ui_buf ~= -1
      end)

      expected = h.load_fixture("fixtures/request_2_verbose.txt")
      result = h.get_buf_lines(ui_buf):to_string()

      assert.is_same(2, curl.requests_no)
      assert.is_same(expected, result)
    end)

    it("it substitues document variables and does authorization", function()
      assert.is_true(vim.fn.executable("npm") == 1)

      vim.cmd.edit(h.expand_path("requests/simple.http"))
      CONFIG.options.default_view = "body"

      curl.stub({
        ["https://httpbin.org/simple"] = {
          body = h.load_fixture("fixtures/simple_body.txt"),
        },
      })

      kulala.run()
      jobstart.wait(3000, function()
        ui_buf = vim.fn.bufnr(GLOBALS.UI_ID)
        return ui_buf ~= -1
      end)

      local expected_request = h.load_fixture("fixtures/simple_request.txt"):to_object().current_request
      local computed_request = DB.data.current_request

      expected = h.load_fixture("fixtures/simple_body.txt")
      result = h.get_buf_lines(ui_buf):to_string()

      assert.is_same(expected_request.headers, computed_request.headers)
      assert.is_same(expected_request.body_computed, computed_request.body_computed)
      assert.is_same(expected, result)
    end)

    it("sets env variable with @env-stdin-cmd", function()
      vim.cmd.edit(h.expand_path("requests/chain.http"))
      CONFIG.options.default_view = "body"

      curl.stub({
        ["https://httpbin.org/chain_1"] = {
          body = h.load_fixture("fixtures/chain_1_body.txt"),
        },
        ["https://httpbin.org/chain_2"] = {
          body = h.load_fixture("fixtures/chain_2_body.txt"),
        },
      })

      kulala.run_all()
      system:wait(3000, function()
        ui_buf = vim.fn.bufnr(GLOBALS.UI_ID)
        return curl.requests_no == 2 and ui_buf ~= -1
      end)

      local expected_request = h.load_fixture("fixtures/chain_2_request.txt"):to_object().current_request
      local computed_request = DB.data.current_request

      expected = h.load_fixture("fixtures/chain_2_body.txt")
      result = h.get_buf_lines(ui_buf):to_string()

      assert.is_same(expected_request.body_computed, computed_request.body_computed)
      assert.is_same(expected, result)
    end)

    it("sets environment variables from response", function()
      vim.cmd.edit(h.expand_path("requests/advanced_A.http"))
      CONFIG.options.default_view = "body"

      curl.stub({
        ["https://httpbin.org/advanced_1"] = {
          body = h.load_fixture("fixtures/advanced_A_1_body.txt"),
        },
        ["https://httpbin.org/advanced_2"] = {
          body = h.load_fixture("fixtures/advanced_A_2_body.txt"),
        },
      })

      kulala.run_all()
      system:wait(3000, function()
        ui_buf = vim.fn.bufnr(GLOBALS.UI_ID)
        return curl.requests_no == 2 and ui_buf ~= -1
      end)

      local expected_request = h.load_fixture("fixtures/advanced_A_2_request.txt"):to_object().current_request
      local computed_request = DB.data.current_request

      expected = h.load_fixture("fixtures/advanced_A_2_body.txt")
      result = h.get_buf_lines(ui_buf):to_string()

      assert.is_same(expected_request.body_computed, computed_request.body_computed)
      assert.is_same(result, expected)
    end)

    it("substitutes http.client.json variables, accesses request/response from js and logs to client", function()
      vim.cmd.edit(h.expand_path("requests/advanced_B.http"))
      CONFIG.options.default_view = "body"

      curl.stub({
        ["https://httpbin.org/advanced_b"] = {
          body = h.load_fixture("fixtures/advanced_B_body.txt"),
        },
      })

      kulala.run_all()
      system:wait(3000, function()
        ui_buf = vim.fn.bufnr(GLOBALS.UI_ID)
        return curl.requests_no == 2 and ui_buf ~= -1
      end)

      local expected_request = h.load_fixture("fixtures/advanced_B_request.txt"):to_object().current_request
      local computed_request = DB.data.current_request

      expected = h.load_fixture("fixtures/advanced_B_body.txt")
      result = h.get_buf_lines(ui_buf):to_string()

      assert.is_same(expected_request.body_computed, computed_request.body_computed)
      assert.is_same(result, expected)
      assert.is_true(notify.has_message("Foobar"))
      assert.is_true(notify.has_message("Thu, 30 Jan 2025 16:21:56 GMT"))
    end)

    it("load a file with @file-to-variable ", function()
      vim.cmd.edit(h.expand_path("requests/advanced_C.http"))
      CONFIG.options.default_view = "body"

      curl.stub({
        ["https://httpbin.org/advanced_c"] = {
          body = h.load_fixture("fixtures/advanced_C_body.txt"),
        },
      })

      kulala.run_all()
      system:wait(3000, function()
        ui_buf = vim.fn.bufnr(GLOBALS.UI_ID)
        return curl.requests_no == 2 and ui_buf ~= -1
      end)

      local expected_request = h.load_fixture("fixtures/advanced_C_request.txt"):to_object().current_request
      local computed_request = DB.data.current_request

      expected = h.load_fixture("fixtures/advanced_C_body.txt")
      result = h.get_buf_lines(ui_buf):to_string()

      assert.is_same(computed_request.body_computed, expected_request.body_computed)
      assert.is_same(result, expected)
    end)
  end)
end)
