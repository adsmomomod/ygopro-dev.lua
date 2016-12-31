--
-- =====================================================================
--
--  !! チェーンを組まない処理いろいろ
--
-- =====================================================================
--

--c:RegisterNewEffect{ dev.effect.FieldLeaveRedirect, dest=LOCATION_REMOVED, owner=est:GetHandler() }

-- フィールドから離れた場合[除外される/手札に戻る/デッキに戻る]
function dev.effect.FieldLeaveRedirect( self, args )
	dev.effect.Construct( nil, args )
	self:SetType(EFFECT_TYPE_SINGLE)
	self:SetCode(EFFECT_LEAVE_FIELD_REDIRECT)
	self:SetProperty(EFFECT_FLAG_CANNOT_DISABLE)
	self:SetReset(RESET_EVENT+0x47e0000)
	self:SetValue(dev.option_arg(args.dest, LOCATION_REMOVED))
end

