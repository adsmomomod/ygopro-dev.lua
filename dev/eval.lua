--
--
--  eval
--
--

-- 値ならそのまま、関数ならf(...)を実行、テーブルならt:Eval(...)を実行する
function dev.eval( val, ... )
	local t=type(val)
	if t=="table" then
		if val.Eval==nil then 
			dev.print(val.__classname, ":Eval関数がありません")
			return nil
		else 
			return val:Eval(...) 
		end
	elseif t=="function" then
		return val(...)
	else
		return val
	end
end

-- 
dev.expr = dev.new_class(
{
	__init = function( self, args )
		dev.require( args, "table" )
		self.operand = args
	end,
	
	Eval = function( self, ... )
		local args={}
		for i, o in ipairs( self.operand ) do
			args[i]=dev.eval( o, ... )
		end
		return self.Operation( table.unpack(args) )
	end,
	
	Operation = nil 
})

function dev.bindexpr( f )
	return dev.new_class( dev.expr, { Operation = f } )
end
	
dev.add = dev.bindexpr( function(l,r) return l+r end )
dev.sub = dev.bindexpr( function(l,r) return l-r end )
dev.mul = dev.bindexpr( function(l,r) return l*r end )
dev.div = dev.bindexpr( function(l,r) return l/r end )
dev.mod = dev.bindexpr( function(l,r) return l%r end )
dev.pow = dev.bindexpr( function(l,r) return l^r end )

dev.eq	= dev.bindexpr( function(l,r) return l==r end )
dev.lt	= dev.bindexpr( function(l,r) return l<r end )
dev.le	= dev.bindexpr( function(l,r) return l<=r end )
dev.ne 	= dev.bindexpr( function(l,r) return l~=r end )
dev.gt	= dev.bindexpr( function(l,r) return l>r end )
dev.ge 	= dev.bindexpr( function(l,r) return l>=r end )

dev.eq0 = dev.bindexpr( function(a) return a==0 end )
dev.ne0 = dev.bindexpr( function(a) return a~=0 end )
dev.gt0 = dev.bindexpr( function(a) return a>0 end )

-- requrieで使える
function dev.eval_able(class)
	return { class, { Eval="function" } }
end
