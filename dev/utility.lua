--
--
-- 定数
--
--
-- ascode
dev.ascost       		= 0x0001
dev.aseffect     		= 0x0002
dev.astarget			= 0x0004
dev.asoption			= 0x0010
dev.asmask       		= 0x00FF
--
dev.oncost				= 0x0001
dev.ontarget			= 0x0002
dev.onoperation			= 0x0004
dev.oncond				= 0x0008
dev.onvalue				= 0x0010

-- カード集合
dev.excepthandler		= 0x0100
-- オペレーション
dev.requirealltarget	= 0x1000
dev.hintsel				= 0x2000

--
--
-- ユーティリティ
--
--
function dev.option_arg(v,defv)
	if v==nil then return defv
	else return v end
end
function dev.option_val(b,v1,v2)
	if b then return v1
	else return v2 end
end 
function dev.option_field(t,key,defv)
	if t==nil or t[key]==nil then return defv
	else return t[key] end
end

--
--
-- 表示
--
--
-- 型名
function dev.typestr(v)
	if v==nil then 
		return "nil"
	elseif dev.is_class(v) then
		return v.__classname
	elseif type(v)=="userdata" then
		if v.GetAttack~=nil then
			return "Card"
		elseif v.SetCondition~=nil then
			return "Effect"
		elseif v.Merge~=nil then
			return "Group"
		else
			return "userdata"
		end
	else
		return type(v)
	end
end

-- デバッグ表示
function dev.valstr(v)
	local t=dev.typestr(v)
	if v==nil then return "nil"
	elseif t=="Card" then return dev.cardstr(v)
	elseif t=="Group" then return dev.groupstr(v)
	elseif t=="Effect" then return "effect"
	elseif t=="table" then 
		local disp={}
		for k, vv in pairs(v) do 
			local vs=tostring(vv)
			if dev.typestr(vv)~="table" then vs=dev.valstr(vv) end
			table.insert(disp,k.."="..vs) 
		end
		return "{"..table.concat(disp,", ").."}"
	elseif t=="function" then
		local d=debug.getinfo(v,"n")
		return "[function]"..dev.option_arg(d.name, "")
	elseif type(v)=="table" and v.__is_class then
		return "class#"..v.__classname
	else return tostring(v) end
end
function dev.valtypestr(v)
	if v==nil then return "nil"
	else return tostring(v).."["..type(v).."]" end
end

function dev.cardstr(c, bsig)
	local sig=""
	if bsig==true then
		sig="Card: "
	end
	if not c then
		return sig.."nil"
	end
	return sig.."c"..tostring(c:GetCode()).."#L"..tostring(c:GetLevel()).."/"..tostring(c:GetAttack()).."/"..tostring(c:GetDefense())
end
	
function dev.groupstr(gt)
	local g=gt:Clone()
	local i = 1
	local ss = "g"..g:GetCount().."[ "
	local tc=g:GetFirst()
	while tc do
		ss = ss..dev.cardstr(tc)
		if i<g:GetCount() then
			ss = ss..", "
		end
		i = i + 1
		tc=g:GetNext()
	end
	return ss.." ]"
end

--
dev.print_handler = Debug.Message
function dev.set_print_handler(mod, ...)
	dev.print_handler = mod.make_print_handler(...)
end

--
local print_width = 135
function dev.print(...)   
	local n = {...}
	local ss = ""
	for i, s in pairs(n) do
		ss = ss..dev.valstr(s)
	end
	if ss:len()>print_width then
		local i,j = 0, print_width
		local ps=ss:sub(i,j)
		while ps~="" do
			dev.print_handler(ps)
			i = j + 1
			j = i + print_width
			ps=ss:sub(i,j)
		end
	else
		dev.print_handler(ss)
	end
end

function dev.print_card(...)
	local t = {...}
	local n = select("#",...)
	local ss = ""
	for i=1, n do
		ss = ss..dev.cardstr(t[i])
		if i<n then
			ss = ss..", "
		end
	end
	dev.print_handler(ss)
end

function dev.print_group(g,gname)
	gname=dev.option_arg(gname,"g")
	if g==nil then
		dev.print(gname.."はnilです")
		return
	end
	dev.print( gname.." "..dev.groupstr(g) )
end

function dev.print_val(...)  
	local t = {...}
	local n = select("#",...)
	local ss = ""
	for i=1, n do
		ss = ss.."("..tostring(i).."):"..dev.valstr(t[i]).." ["..dev.typestr(t[i]).."]"
		if i<n then
			ss = ss..", "
		end
	end
	dev.print_handler(ss)
end

function dev.print_table(tbl,tblname,maxlevel,level)
	tblname = dev.option_arg(tblname,"table")
	level = dev.option_arg(level,0)
	
	if maxlevel~=nil and level > maxlevel then return end
	
	if tbl==nil then
		Debug.Message(tblname.."はnilです")
		return
	end
	
	-- インデント表示
	local indent=""
	for i = 1, level-1 do
		indent=indent.."　"
	end
	if level>0 then indent=indent.."└" end
	
	-- 値とテーブルを仕訳する
	local tables = {}
	local values = {}
	for k, v in pairs(tbl) do
		if type(v) == "table" then
			table.insert(tables, {key=k, value=v})
		else
			table.insert(values, {key=k, value=v})
		end
	end
	if #tables==0 and #values==0 then
		dev.print_handler(tblname.."は空です")
		return
	end
	
	if level==0 then Debug.Message("------ BEGIN "..tblname.." ---------") end
	local alsorter = function(l, r) return l.key < r.key end
	
	-- 値を名前順に表示
	table.sort(values, alsorter)
	for _, v in pairs(values) do
		dev.print_handler(indent..v.key.." = "..dev.valstr(v.value))
	end
	
	-- テーブルを名前順に表示
	table.sort(tables, alsorter)
	for _, v in pairs(tables) do
		dev.print_handler(indent..v.key.." = {#"..#v.value.."}")
		dev.print_table(v.value,"",maxlevel,level+1)
	end	
	
	if level==0 then Debug.Message("------ END "..tblname.." -----------") end
end

--
-- ビット操作
--
dev.bit = {}
dev.bit.bcontain = function(l,r)
	return bit.band(l,r)==r
end

--
--
-- テーブル操作
--
--
dev.table = {}

-- 再帰的にテーブルを複製する
function dev.table.deepcopy(orig)
    local copy = nil
	local orig_type = type(orig)
    if orig_type == 'table' then
		copy = {}
		for orig_key, orig_value in next, orig, nil do
			copy[dev.table.deepcopy(orig_key)] = dev.table.deepcopy(orig_value)
		end
		setmetatable(copy, dev.table.deepcopy(getmetatable(orig)))
    else -- number, string, boolean, etc
        copy = orig
    end
    return copy
end

-- トップレベルの要素のみ複製、後は同じ実体を参照
function dev.table.shallowcopy(orig)
	local copy = {}
	for k, v in pairs(orig) do
		copy[k] = v
	end
    return copy
end
function dev.table.split_last( tbl )
	if #tbl == 0 then return nil end
	local el = tbl[#tbl]
	table.remove(tbl, #tbl)
	return tbl, el
end
function dev.table.is_same( l, r )
	if l==nil and r==nil then
		return true
	elseif l and r then
		for k, v in pairs(l) do
			local rv = r[v]
			if rv==nil then return false 
			elseif v~=rv then return false
			end
		end
		return true
	else
		return false
	end
end
function dev.table.loop(tbl, f)
    for i, c in ipairs(tbl) do
        if f( i, c )==false then
			return false
		end
    end
	return true
end
function dev.table.sum(tbl, f, start, binop)
	local su=start
	for k, c in pairs(tbl) do	
		if f~=nil then
			c=f(k,c)
		end
		if su==nil then
			su = c
		elseif binop~=nil then
			su = binop( su, c )
		else
			su = su + c
		end
	end
	return su
end
function dev.table.all_of(tbl, f)
	for k, v in pairs(tbl) do
		if not f(k, v) then return false end
	end
	return true
end
function dev.table.merge(t1, t2)
    for k, v in pairs(t2) do
        if (type(v) == "table") and (type(t1[k] or false) == "table") then
            dev.table.merge(t1[k], t2[k])
        else
            t1[k] = v
        end
    end
    return t1
end
function dev.table.find(tbl, pred)
	if type(pred)~="function" then 
		return dev.table.find(tbl, function(v) return v==pred end)
	end	
	for k, v in pairs(tbl) do
		if pred(tbl, pred) then return v, k end
	end
	return nil
end
function dev.table.count(tbl, pred)
	if type(pred)~="function" then 
		return dev.table.find(tbl, function(v) return v==pred end)
	end	
	local cnt=0
	for k, v in pairs(tbl) do
		if pred(tbl, pred) then cnt=cnt+1 end
	end
	return cnt
end
function dev.table.addmeta(t, amt)
	local mt = dev.option_arg(getmetatable(t), {})
	for k, v in pairs(amt) do
		mt[k] = v
	end
	setmetatable(t, mt)
	return t
end

-- ({4,5,6}) -> {[4]=true,[5]=true,[6]=true}
function dev.table.make_value_dict(arr, val)
	val = dev.option_arg(val, true)
	local nt={}
	for _, v in ipairs(arr) do
		nt[v] = val
	end
	return nt
end

-- ({"a","b","c"},{100,200,300}) -> {a=100,b=200,c=300}
function dev.table.insert_array(t, names, values)
	for i, key in ipairs(names) do
		t[key] = values[i]
	end
	return t
end

--
--
-- 効果オブジェクト
--
--
dev.Effect = {}
function dev.Effect.GetValue(e)
	local val=e:GetValue()
	if type(val) == "function" then 
		return val( e, e:GetHandler() )
	end
	return val
end

--
--
-- グループオブジェクト
--
--
dev.Group = {}
function dev.Group.ForEach( g, f, start, binop )
	local su=dev.option_arg(start, 0)
	local c=g:GetFirst()
	while c do
		local r=f( c )
		if su==nil then
			su = r
		elseif binop~=nil then
			su = binop( su, r )
		else
			su = su + r
		end
		c=g:GetNext()
	end
	return su
end
function dev.Group.FlatGroups( tbl )
	local ret=Group.CreateGroup()
	for i, g in ipairs(tbl) do
		if g~=nil then
			ret:Merge(g)
		end
	end
	return ret
end



