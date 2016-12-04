--
-- =====================================================================
--
--  !! カードフィルター
--
-- =====================================================================
--
dev.card_filter = dev.new_class(
{
	__init = function( self, args )
		self.tbl = args
		setmetatable( self, { __call = self.Invoke } )
	end,
	
	Eval = function( self, c, est )
		for k, v in pairs(self.tbl) do
			local api=self.QueryFilterApi( k, v )
			if api~=nil then
				local b=false
				if v==true then b=api( c )
				else b=api( c, v ) end
				
				if not b then
					est:OpDebugDisp(k, ": ", c, "に対して失敗")
				end
				return b
			else
				est:OpDebugDisp(k, ": そのようなフィルター関数は存在しません")
				return false
			end
		end
	end,
	
	QueryFilterApi = function( key, val )
		local api
		if type(val)=="table" then
			
		end
	
		local is = "Is"..key
		if Card[is]~=nil then
			api = Card[is]
			args = { true, table.unpack(valargs) }
		end
			
		local get = "Get"..key
		
		
	end,
	
})

dev.match({ 
	[0] = dev.match({ AttackAbove = 2800, DefenceBelow = 1000 })
	[1] = dev.not_match({ Forbidden = true })
})

dev.match({ AttackAbove = 2800, DefenceBelow = 1000 }):or_({  }):and_not({ Forbidden = true })

--
--
--
dev.card_filter_api = 
{
	-- 表示形式
	attack_pos	= @filter c:IsAttackPos() end,
	defense_pos	= @filter c:IsDefencePos() end,
	faceup 		= @filter c:IsFaceup() end,
	facedown 	= @filter c:IsFacedown() end,
	pos			= function( c, v ) 
					return bit.btest( c:GetPosition(), v ) end,
	
	-- 攻守
	attack		= function( c, v ) return c:GetAttack() == v end,
					
	
}



