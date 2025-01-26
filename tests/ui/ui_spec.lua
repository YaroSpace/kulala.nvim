local GLOBALS = require("kulala.globals")
local CONFIG = require("kulala.config")
local kulala = require("kulala")

local h = require("test_helper.ui")
local s = require("test_helper.stubs")

local assert = require("luassert")

describe("kulala.ui", function()
  describe("show output of requests", function()
    local jobstart, system, fs
    local result, expected, ui_buf

    before_each(function()
      fs = s.Fs:stub_read_file({
        [GLOBALS.HEADERS_FILE] = h.to_string([[
          HTTP/1.1 200 OK
          Date: Sun, 26 Jan 2025 00:14:41 GMT
          Transfer-Encoding: chunked
          Server: Jetty(9.4.36.v20210114)
        ]]),
        [GLOBALS.BODY_FILE] = "Hello, World!\nRequest #1",
      })

      jobstart = s.Jobstart:stub("test_cmd", {
        on_stdout = h.load_fixture("stats.json"),
        on_stderr = h.load_fixture("request_1_errors.txt"),
        on_exit = 0,
      })

      system = s.System:stub("test_cmd", {
        stdout = h.load_fixture("stats.json", false),
        on_call = function(self)
          self.requests_no = self.requests_no + 1

          local request_url = self.args[1][#self.args[1]]
          vim.list_extend(self.requests, { request_url })

          local fixture = ("request_%s_errors.txt"):format(self.requests_no)
          self.stderr = h.load_fixture(fixture, false)

          fs:stub_read_file({
            [GLOBALS.BODY_FILE] = ("Hello, World!\nRequest #%s"):format(self.requests_no),
          })
        end,
      })
    end)

    after_each(function()
      h.delete_all_bufs()
      fs:read_file_reset()

      jobstart:reset()
      system:reset()
    end)

    it("shows request output in verbose mode for run_one", function()
      local lines = h.to_table([[
        GET http://localhost:3001/greeting
      ]])

      h.create_buf(lines, "test.http")
      CONFIG.options.default_view = "verbose"

      kulala.run()
      jobstart:wait(3000, function()
        ui_buf = vim.fn.bufnr(GLOBALS.UI_ID)
        return ui_buf > 0
      end)

      result = h.to_string(h.get_buf_lines(ui_buf), false)
      expected = h.load_fixture("request_1_verbose.txt", false)

      assert.is_same(expected, result)
    end)

    it("shows last request output in verbose mode for run_all", function()
      local lines = h.to_table([[
        GET http://localhost:3001/greeting

        ###

        GET http://localhost:3001/echo
      ]])

      h.create_buf(lines, "test.http")
      CONFIG.options.default_view = "verbose"

      kulala.run_all()

      system:wait(3000, function()
        ui_buf = vim.fn.bufnr(GLOBALS.UI_ID)
        return system.requests_no == 2 and ui_buf ~= -1
      end)

      expected = h.load_fixture("request_2_verbose.txt", false)
      result = h.to_string(h.get_buf_lines(ui_buf), false)

      assert.is_same(2, system.requests_no)
      assert.is_same(expected, result)
    end)
  end)
end)
