--
-- =====================================================================
--
--  !! チェーンを組まない処理いろいろ
--
-- =====================================================================
--

--
--
-- 永続効果・ルール効果クラス
--
--
local cond_handler			= { "effect" }
local target_handler 		= { "effect", "tc" }
local value_handler 		= { "effect" }
local value_handler_card 	= { "effect", "tc" }
local value_handler_effect 	= { "effect", "e" }

-- カードを対象にかかる効果
dev.effect_class.aura = dev.new_class(
{
	__init = function( self, tgargs, valargs, conargs )
		self.tgargs  = dev.option_arg( tgargs, target_handler )
		self.valargs = dev.option_arg( valargs, value_handler )
		self.conargs = dev.option_arg( conargs, cond_handler )
		
		if valargs then
			self:SetProcTarget( true )
		end
	end,

	-- effect_stateを生成 [filter_effect系に対応]
	InitStateObject = function( self, est, ... )
		local a
		if est.timing == dev.oncond then
			a = self.conargs
		elseif est.timing == dev.ontarget then
			a = self.tgargs
		elseif est.timing == dev.onvalue then
			a = self.valargs
		end
		if a==nil then return end
		
		dev.table.insert_array( est, a, {...} )
		
		if a.tc then est.tc = est[a.tc] end
		if a.tp then est.tp = est[a.tp] end
		if est.tc==nil then est.tc = est:GetHandler() end
		if est.tp==nil then est.tp = est:GetEffect():GetHandlerPlayer() end
	end, 
	
	-- target
	SetTarget = function( self, filter )
		self:SetTargetHandler( dev.HandlerFromFilter(filter) )
	end,

	-- value
	SetProcTarget = function( self, filter )
		if filter==true then 
			self:SetValue(1)
		else 
			self:SetValue(nil)
			self:SetValueHandler( dev.HandlerFromFilter(filter) )
		end
	end,
})

-- カード専門
local aura_effect_initer = function( code, a, b, c, d )
	return function( self )
		self:Inherit( dev.effect_class.aura, a, b, c, d )
		self:SetCode( code )
		self:SetType( EFFECT_TYPE_SINGLE )
	end
end
dev.effect.Aura = aura_effect_initer

-- ==========================================================
--
-- 効果コンストラクタ
--
-- ==========================================================
--
-- ステータス変更
--
-- atk
dev.effect.UpdateAttack				= aura_effect_initer(EFFECT_UPDATE_ATTACK)
dev.effect.SetAttack				= aura_effect_initer(EFFECT_SET_ATTACK)
dev.effect.SetAttackFinal			= aura_effect_initer(EFFECT_SET_ATTACK_FINAL)
dev.effect.SetBaseAttack			= aura_effect_initer(EFFECT_SET_BASE_ATTACK)
-- def
dev.effect.UpdateDefense			= aura_effect_initer(EFFECT_UPDATE_DEFENSE)
dev.effect.SetDefense				= aura_effect_initer(EFFECT_SET_DEFENSE)
dev.effect.SetDefenseFinal			= aura_effect_initer(EFFECT_SET_DEFENSE_FINAL)
dev.effect.SetBaseDefense			= aura_effect_initer(EFFECT_SET_BASE_DEFENSE)
-- ad
dev.effect.SwapAD					= aura_effect_initer(EFFECT_SWAP_AD)
dev.effect.SwapBaseAD				= aura_effect_initer(EFFECT_SWAP_BASE_AD)
dev.effect.ReverseUpdateAD			= aura_effect_initer(EFFECT_REVERSE_UPDATE)
-- level
dev.effect.UpdateLevel				= aura_effect_initer(EFFECT_UPDATE_LEVEL)
dev.effect.SetLevel					= aura_effect_initer(EFFECT_CHANGE_LEVEL)
dev.effect.SetLevelFinal			= aura_effect_initer(EFFECT_CHANGE_LEVEL_FINAL)
-- rank             		
dev.effect.UpdateRank				= aura_effect_initer(EFFECT_UPDATE_RANK)
dev.effect.SetRank					= aura_effect_initer(EFFECT_CHANGE_RANK)
dev.effect.SetRankFinal				= aura_effect_initer(EFFECT_CHANGE_RANK_FINAL)
-- lscale           
dev.effect.UpdateLeftScale			= aura_effect_initer(EFFECT_UPDATE_LSCALE)
dev.effect.SetLeftScale				= aura_effect_initer(EFFECT_CHANGE_LSCALE)	
-- rscale           		
dev.effect.UpdateRightScale			= aura_effect_initer(EFFECT_UPDATE_RSCALE)
dev.effect.SetRightScale			= aura_effect_initer(EFFECT_CHANGE_RSCALE)	
-- race  
dev.effect.SetRace					= aura_effect_initer(EFFECT_CHANGE_RACE)
dev.effect.AddRace					= aura_effect_initer(EFFECT_ADD_RACE)
dev.effect.RemoveRace				= aura_effect_initer(EFFECT_REMOVE_RACE)
-- attr    
dev.effect.SetAttribute				= aura_effect_initer(EFFECT_CHANGE_ATTRIBUTE)
dev.effect.AddAttribute				= aura_effect_initer(EFFECT_ADD_ATTRIBUTE)
dev.effect.RemoveAttribute			= aura_effect_initer(EFFECT_REMOVE_ATTRIBUTE)
-- type
dev.effect.SetType					= aura_effect_initer(EFFECT_CHANGE_TYPE)
dev.effect.AddType					= aura_effect_initer(EFFECT_ADD_TYPE)
dev.effect.RemoveType				= aura_effect_initer(EFFECT_REMOVE_TYPE)
-- code
dev.effect.SetCode					= aura_effect_initer(EFFECT_CHANGE_CODE)
dev.effect.AddCode					= aura_effect_initer(EFFECT_ADD_CODE)
-- setcode	
dev.effect.AddSetCode				= aura_effect_initer(EFFECT_ADD_SETCODE)

--
-- 戦闘
--
dev.effect.MustAttack				= aura_effect_initer(EFFECT_MUST_ATTACK)
dev.effect.FirstAttack				= aura_effect_initer(EFFECT_FIRST_ATTACK)
dev.effect.Pierce					= aura_effect_initer(EFFECT_PIERCE)
dev.effect.BattleDamageToEffect 	= aura_effect_initer(EFFECT_BATTLE_DAMAGE_TO_EFFECT)
dev.effect.AttackAll				= aura_effect_initer(EFFECT_ATTACK_ALL, nil, value_handler_card)
dev.effect.MustBeAttacked	 		= aura_effect_initer(EFFECT_MUST_BE_ATTACKED, nil, value_handler_card)
dev.effect.AvoidBattleDamage 		= aura_effect_initer(EFFECT_AVOID_BATTLE_DAMAGE, nil, value_handler_card)
dev.effect.ReflectBattleDamage 		= aura_effect_initer(EFFECT_REFLECT_BATTLE_DAMAGE, nil, value_handler_card)
dev.effect.NoBattleDamage			= aura_effect_initer(EFFECT_NO_BATTLE_DAMAGE)
dev.effect.IgnoreBattleTarget		= aura_effect_initer(EFFECT_IGNORE_BATTLE_TARGET)

--
-- 耐性/禁止
--
dev.effect.CannotSummon = aura_effect_initer( 
	EFFECT_CANNOT_SUMMON, 
	{ "effect", "tc", "tp", "sumtype" }
)
dev.effect.CannotSpecialSummon = aura_effect_initer( 
	EFFECT_CANNOT_SPECIAL_SUMMON, 
	{ "effect", "tc", "tp", "sumtype", "pos", "destp", "sumeffect" }
)
dev.effect.CannotFlipSummon = aura_effect_initer( 
	EFFECT_CANNOT_SUMMON, 
	{ "effect", "tc", "tp" }
)
dev.effect.CannotSetMonster = aura_effect_initer( 
	EFFECT_CANNOT_MSET, 
	{ "effect", "tc", "tp", "sumtype" }
)
dev.effect.CannotSetST = aura_effect_initer( 
	EFFECT_CANNOT_SSET, 
	{ "effect", "tc", "tp" }
)
dev.effect.CannotDraw 					= aura_effect_initer(EFFECT_CANNOT_DRAW)
dev.effect.CannotDiscardDeck 			= aura_effect_initer(EFFECT_CANNOT_DISCARD_DECK)
dev.effect.CannotDiscardHand 			= aura_effect_initer(EFFECT_CANNOT_DISCARD_DECK, {"effect", "tc", "reason_effect", "reason"})
dev.effect.CannotRelease				= aura_effect_initer(EFFECT_CANNOT_RELEASE)

dev.effect.CannotRemove					= aura_effect_initer(EFFECT_CANNOT_REMOVE, {"effect", "tc", "tp"})
dev.effect.CannotToDeck					= aura_effect_initer(EFFECT_CANNOT_TO_DECK, {"effect", "tc", "tp"})
dev.effect.CannotToHand					= aura_effect_initer(EFFECT_CANNOT_TO_HAND, {"effect", "tc", "tp"})
dev.effect.CannotToGrave				= aura_effect_initer(EFFECT_CANNOT_TO_GRAVE, {"effect", "tc", "tp"})

dev.effect.CannotDestroy				= aura_effect_initer(EFFECT_INDESTRUCTABLE, nil, {"effect","reason","reason_player"})
dev.effect.CannotDestroyByBattle		= aura_effect_initer(EFFECT_INDESTRUCTABLE_BATTLE, nil, value_handler_card)
dev.effect.CannotDestroyByEffect		= aura_effect_initer(EFFECT_INDESTRUCTABLE_EFFECT, nil, {"effect", "tp", "tc"})
dev.effect.CannotDestroyCount			= aura_effect_initer(EFFECT_INDESTRUCTABLE_COUNT, nil, {"effect", "reason", "reason_player"})

dev.effect.CannotDisableSummon 			= aura_effect_initer(EFFECT_CANNOT_DISABLE_SUMMON)
dev.effect.CannotDisableSpecialSummon 	= aura_effect_initer(EFFECT_CANNOT_DISABLE_SPSUMMON)
dev.effect.CannotDisableFlipSummon 		= aura_effect_initer(EFFECT_CANNOT_DISABLE_FLIP_SUMMON)

dev.effect.CannotDisable				= aura_effect_initer(EFFECT_CANNOT_DISABLE)    -- 
dev.effect.CannotDisableEffect			= aura_effect_initer(EFFECT_CANNOT_DISEFFECT, nil, {"effect", "chaincount"})  --
dev.effect.CannotNegate					= aura_effect_initer(EFFECT_CANNOT_INACTIVATE, nil, {"effect", "chaincount"}) --

dev.effect.CannotTrigger				= aura_effect_initer(EFFECT_CANNOT_TRIGGER)  -- カードは効果を発動できない
dev.effect.CannotActivate				= aura_effect_initer(EFFECT_CANNOT_ACTIVATE, nil, {"effect", "te", "tp"}) -- プレイヤーは効果を発動できない

dev.effect.CannotBeEffectTarget			= aura_effect_initer(EFFECT_CANNOT_BE_EFFECT_TARGET, nil, {"effect", "te", "tp"}) -- 違い？
dev.effect.CannotBeBattleTarget			= aura_effect_initer(EFFECT_CANNOT_BE_BATTLE_TARGET, nil, value_handler_card ) --

dev.effect.CannotSelectEffectTarget		= aura_effect_initer(EFFECT_CANNOT_SELECT_EFFECT_TARGET, nil, {"effect", "te", "tc"}) --
dev.effect.CannotSelectBattleTarget		= aura_effect_initer(EFFECT_CANNOT_SELECT_BATTLE_TARGET, nil, value_handler_card ) --

dev.effect.CannotAttack					= aura_effect_initer(EFFECT_CANNOT_ATTACK)
dev.effect.CannotAttackAnounce			= aura_effect_initer(EFFECT_CANNOT_ATTACK_ANNOUNCE)
dev.effect.CannotDirectAttack			= aura_effect_initer(EFFECT_CANNOT_DIRECT_ATTACK)

dev.effect.CannotConductBP				= aura_effect_initer(EFFECT_CANNOT_BP)
dev.effect.CannotConductM2				= aura_effect_initer(EFFECT_CANNOT_M2)
dev.effect.CannotConductEP				= aura_effect_initer(EFFECT_CANNOT_EP)

--
-- 無効
--
-- カードの効果を無効にする
dev.effect.Disable = aura_effect_initer(EFFECT_DISABLE)
-- そのカードが発動した効果を無効にする（これ単体では使わない？）
dev.effect.DisableChain = aura_effect_initer(EFFECT_DISABLE_CHAIN)
-- EFFECT_DISABLE_CHAINを登録する
dev.effect.DisableEffect = function( self )
	self:Inherit( aura_effect_initer( EFFECT_DISABLE_EFFECT ) )
	self.SetDisableChainReset = self.SetValue
end


--
-- 無敵
--
dev.effect.Immune = aura_effect_initer( EFFECT_IMMUNE_EFFECT )

--
-- 別の場所に転送
--
local redirect_aura_initer = function( code )
	return function( self )
		self:Inherit( dev.effect_class.aura, nil, value_handler_card )
		self:SetCode( code )
		self.SetDest = self.SetValue -- 行き先を返す関数でもOK
		self.SetProcTarget = nil
	end
end
dev.effect.LeaveFieldRedirect 		= redirect_aura_initer( EFFECT_LEAVE_FIELD_REDIRECT )
dev.effect.BattleDestroyRedirect 	= redirect_aura_initer( EFFECT_BATTLE_DESTROY_REDIRECT )
dev.effect.RemoveRedirect 			= redirect_aura_initer( EFFECT_REMOVE_REDIRECT )
dev.effect.ToDeckRedirect 			= redirect_aura_initer( EFFECT_TO_DECK_REDIRECT )
dev.effect.ToGraveRedirect 			= redirect_aura_initer( EFFECT_TO_GRAVE_REDIRECT )
dev.effect.ToHandRedirect 			= redirect_aura_initer( EFFECT_TO_HAND_REDIRECT )

--
-- 装備
--
dev.effect.EquipLimit = aura_effect_initer( EFFECT_EQUIP_LIMIT, nil, value_handler_card )


