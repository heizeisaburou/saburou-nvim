-- hzsr.edt.io.types

---@class hzsr.edt.io.reveal_opts
---@field reveal_mode hzsr.edt.reveal.mode
---@field reveal_strategy hzsr.edt.reveal.strategy
---@field reveal_hl string
---@field async boolean

---@class hzsr.edt.io.out
---@field status hzsr.edt.io.status
---@field bufnr integer
---@field path? string
---@field msg? string

---@class hzsr.edt.io.batch_report
---@field ok boolean
---@field tried integer[]
---@field success integer[]
---@field rejected integer[]
---@field cancelled integer?
---@field errored integer[]
---@field results table<integer, table>

---@class hzsr.edt.io.save.out : hzsr.edt.io.out
---@field write_status? hzsr.buf.write.status
---@field existing_buf? integer

---@class hzsr.edt.io.close.out : hzsr.edt.io.out
---@field save_status? hzsr.edt.io.status
---@field write_status? hzsr.buf.write.status
---@field existing_buf? integer
