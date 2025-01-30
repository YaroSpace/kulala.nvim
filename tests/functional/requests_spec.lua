local GLOBALS = require("kulala.globals")
local CONFIG = require("kulala.config")
local DB = require("kulala.db")
local kulala = require("kulala")

local h = require("test_helper.ui")
local s = require("test_helper.stubs")

local assert = require("luassert")

describe("requests", function()
  describe("show output of requests", function()
    local curl, jobstart, system
    local result, expected, ui_buf

    before_each(function()
      h.delete_all_bufs()

      curl = s.Curl:stub({
        ["*"] = {
          headers = h.load_fixture("fixtures/request_1_headers.txt"),
          stats = h.load_fixture("fixtures/request_1_stats.txt"),
        },
        ["http://localhost:3001/greeting"] = {
          body = h.load_fixture("fixtures/request_1_body.txt"),
          errors = h.load_fixture("fixtures/request_1_errors.txt"),
        },
        ["http://localhost:3001/echo"] = {
          body = h.load_fixture("fixtures/request_2_body.txt"),
          errors = h.load_fixture("fixtures/request_2_errors.txt"),
        },
      })

      jobstart = s.Jobstart:stub({ "curl" }, {
        on_call = function(self)
          curl:request(self)
        end,
        on_exit = 0,
      })

      system = s.System:stub({ "curl" }, {
        on_call = function(self)
          curl:request(self)
        end,
      })
    end)

    after_each(function()
      h.delete_all_bufs()
      curl:reset()
      jobstart:reset()
      system:reset()
    end)

    it("shows request output in verbose mode for run_one", function()
      local lines = h.to_table(
        [[
        GET http://localhost:3001/greeting
      ]],
        true
      )

      h.create_buf(lines, "test.http")
      CONFIG.options.default_view = "verbose"
      CONFIG.options.display_mode = "float"

      kulala.run()
      jobstart:wait(3000, function()
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
        GET http://localhost:3001/greeting

        ###

        GET http://localhost:3001/echo
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

    it("perfoms simple .http requests", function()
      vim.cmd.edit(h.expand_path("requests/simple.http"))
      CONFIG.options.default_view = "body"

      curl = s.Curl:stub({
        ["https://httpbin.org/post"] = {
          headers = h.load_fixture("fixtures/simple_response_headers.txt"),
          body = h.load_fixture("fixtures/simple_response_body.txt"),
        },
      })

      kulala.run()
      jobstart:wait(3000, function()
        ui_buf = vim.fn.bufnr(GLOBALS.UI_ID)
        return ui_buf ~= -1
      end)

      local expected_request = h.load_fixture("fixtures/simple_request_obj.txt"):to_object().current_request
      local result_request = DB.data.current_request

      expected = h.load_fixture("fixtures/simple_response_body.txt")
      result = h.get_buf_lines(ui_buf):to_string()

      assert.is_same(expected_request.headers, result_request.headers)
      assert.is_same(expected_request.body_computed, result_request.body_computed)

      assert.is_same(expected, result)
    end)

    it("perfoms chained .http requests", function()
      vim.cmd.edit(h.expand_path("/home/yaro/projects/kulala.nvim/tests/functional/requests/chain.http"))
      CONFIG.options.default_view = "body"

      curl = s.Curl:stub({
        ["https://httpbin.org/post_1"] = {
          headers = h.load_fixture("fixtures/chain_response_1_headers.txt"),
          body = h.load_fixture("fixtures/chain_response_1_body.txt"),
        },
        ["https://httpbin.org/post_2"] = {
          headers = h.load_fixture("fixtures/chain_response_2_headers.txt"),
          body = h.load_fixture("fixtures/chain_response_2_body.txt"),
        },
      })

      kulala.run_all()
      system:wait(3000, function()
        ui_buf = vim.fn.bufnr(GLOBALS.UI_ID)
        return system.requsets_no == 2 and ui_buf ~= -1
      end)

      local expected_request = h.load_fixture("fixtures/chain_request_2_obj.txt"):to_object().current_request
      local result_request = DB.data.current_request

      expected = h.load_fixture("fixtures/chain_response_2_body.txt")
      result = h.get_buf_lines(ui_buf):to_string()

      assert.is_same(expected_request.headers, result_request.headers)
      assert.is_same(expected_request.body_computed, result_request.body_computed)

      assert.is_same(expected, result)
    end)

    it("perfoms advanced .http requests", function()
      -- vim.cmd.edit(h.expand_path("/requests/simple.http"))
    end)
  end)
end)
