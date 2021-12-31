local charset = {}

-- qwertyuiopasdfghjklzxcvbnmQWERTYUIOPASDFGHJKLZXCVBNM1234567890
for i = 48,  57 do table.insert(charset, string.char(i)) end
for i = 65,  90 do table.insert(charset, string.char(i)) end
for i = 97, 122 do table.insert(charset, string.char(i)) end

function string.random(length)
  math.randomseed(os.time())

  if length > 0 then
    return string.random(length - 1) .. charset[math.random(1, #charset)]
  else
    return ""
  end
end

function sleep(n)
  os.execute("sleep " .. tonumber(n))
end
local name = io.read()


io.write("20 text/gemini\n\r")
for i = 0, 1000,1
do
  io.write(string.random(1000))
  io.write("\n")
end
return