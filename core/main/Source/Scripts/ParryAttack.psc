Scriptname ParryAttack extends ActiveMagicEffect

;==========================
; 📌 필요한 속성 (Properties) 정의
;==========================
Actor Property PlayerRef Auto  
GlobalVariable Property Parrying Auto  
GlobalVariable Property ParryHit Auto  
Explosion Property ParryBlockExplosion Auto  

;Spell Property TimeSlowSpell Auto  
Spell Property ParryAttackDamage Auto  
Spell Property DamageImmunity Auto  

Perk Property StaggerResistance Auto  ; ✅ 스태거 저항 퍼크 (Stagger Resistance Perk)


;==========================
; 🔧 변수 선언 | variable declaration
;==========================
Actor ParryActor
Bool Parry = false    ; 패링 유지 여부 (Whether to maintain paring)
Bool Parry2 = false   ; 반격(파워 어택) 여부 (Whether to counterattack (power attack))
Bool IsDodging = false  
Actor LastAggressor  

int StaminaRegenSteps = 3   ; 3단계로 나누어 회복 (Recovery divided into 3 stages)
float RegenStep = 0.0      ; 1회 회복량 고정 (10씩 3회) (Fixed recovery amount per time (3 times 10 each))


;==========================
; 🎬 마법 효과 시작 시 이벤트 | Event when magic effect starts
;==========================
Event OnEffectStart(Actor akTarget, Actor akCaster)
    ParryActor = akTarget
    RegisterForAnimationEvent(ParryActor, "ParryStart")
    RegisterForAnimationEvent(ParryActor, "ParryStart2")
    RegisterForAnimationEvent(ParryActor, "ParryStop")
    RegisterForAnimationEvent(ParryActor, "attackStop")
    RegisterForAnimationEvent(ParryActor, "FH_Dodge1")
EndEvent


;==========================
; 🎬 마법 효과 종료 시 이벤트 | Event when magic effect ends
;==========================
Event OnEffectFinish(Actor akTarget, Actor akCaster)
    if ParryActor
        UnregisterForAnimationEvent(ParryActor, "ParryStart")
        UnregisterForAnimationEvent(ParryActor, "ParryStart2")
        UnregisterForAnimationEvent(ParryActor, "ParryStop")
        UnregisterForAnimationEvent(ParryActor, "attackStop")
        UnregisterForAnimationEvent(ParryActor, "FH_Dodge1")
    endif

    if LastAggressor
        UnregisterForAnimationEvent(LastAggressor, "HitFrame")
    endif

    ParryActor = None
    LastAggressor = None
EndEvent


;==========================
; ⚡ 스태미나 회복 비동기 실행 | Stamina recovery asynchronous execution
;==========================
Event OnUpdate()
    if (StaminaRegenSteps > 0)
        PlayerRef.RestoreActorValue("Stamina", RegenStep)
        StaminaRegenSteps -= 1
        if (StaminaRegenSteps > 0)
            RegisterForSingleUpdate(0.5)
        endif
    endif
EndEvent


;==========================
; 🎭 애니메이션 이벤트 처리 | Animation event handling
;==========================
Event OnAnimationEvent(ObjectReference akSource, string asEventName)
    if (akSource == ParryActor)
        if (asEventName == "ParryStart")
            ParryActor.SetAnimationVariableBool("isBlocking", true)
            PlayerRef.AddSpell(DamageImmunity, false)
            Parry = true
            Parrying.SetValue(1)
            PlayerRef.AddPerk(StaggerResistance)
            PlayerRef.DamageActorValue("Stamina", 20.0)

        elseif (asEventName == "ParryStart2")
            ParryActor.SetAnimationVariableBool("isBlocking", true)
            PlayerRef.AddSpell(DamageImmunity, false)
            Parry = true
            Parry2 = true
            Parrying.SetValue(0)
            PlayerRef.AddPerk(StaggerResistance)
            PlayerRef.DamageActorValue("Stamina", 20.0)

        elseif (asEventName == "ParryStop" || asEventName == "attackStop")
            ParryActor.SetAnimationVariableBool("isBlocking", false)
            Parry = false
            Parry2 = false
            PlayerRef.RemoveSpell(DamageImmunity)
            Parrying.SetValue(0)
            PlayerRef.RemovePerk(StaggerResistance)

        elseif (asEventName == "FH_Dodge1")
            IsDodging = true
            PlayerRef.SetGhost(true)
            PlayerRef.DamageActorValue("Stamina", 20.0)
            
            FindAndTrackEnemy()

            Utility.Wait(0.3)
            PlayerRef.SetGhost(false)
            IsDodging = false

            if LastAggressor
                UnregisterForAnimationEvent(LastAggressor, "HitFrame")
            endif
        endif

;    elseif (akSource == LastAggressor && asEventName == "HitFrame" && IsDodging)
;        PlayerRef.AddSpell(TimeSlowSpell, false)
;        Utility.Wait(0.2)
;        PlayerRef.RemoveSpell(TimeSlowSpell)
    endif
EndEvent


;==========================
; ⚔️ 피격 이벤트 처리 | Hit event handling
;==========================
Event OnHit(ObjectReference akAggressor, Form akSource, Projectile akProjectile, bool abPowerAttack, bool abSneakAttack, \
    bool abBashAttack, bool abHitBlocked)

    Actor AggressorActor = akAggressor as Actor

    if Parry == true && abHitBlocked == true
        if ParryActor == PlayerRef
            StaminaRegenSteps = 3
            RegisterForSingleUpdate(0.5)

            if Parry2 == true
                ParryHit.SetValue(2)
                ParryActor.PlaceAtMe(ParryBlockExplosion)
                Debug.SendAnimationEvent(AggressorActor, "recoilStart")
                
                ;PlayerRef.AddSpell(TimeSlowSpell, false)
                PlayerRef.AddSpell(ParryAttackDamage, false)
                Utility.Wait(0.2)
                ;PlayerRef.RemoveSpell(TimeSlowSpell)
                Utility.Wait(1.2)
                PlayerRef.RemoveSpell(ParryAttackDamage)
                PlayerRef.RemoveSpell(DamageImmunity)
                PlayerRef.RemovePerk(StaggerResistance)

                Utility.Wait(0.1)
                ParryHit.SetValue(0)

            else
                if AggressorActor && AggressorActor.GetLeveledActorBase().GetRace().IsPlayable()
                    ParryHit.SetValue(1)
                else
                    ParryHit.SetValue(5)
                endif

                ParryActor.PlaceAtMe(ParryBlockExplosion)
                Debug.SendAnimationEvent(AggressorActor, "recoilStart")
                                
                ;PlayerRef.AddSpell(TimeSlowSpell, false)
                PlayerRef.AddSpell(ParryAttackDamage, false)

                ParryActor.StopTranslation()
                Utility.Wait(0.1)
                Debug.SendAnimationEvent(ParryActor, "attackPowerStartInPlace")
                Utility.Wait(0.1)
                ;PlayerRef.RemoveSpell(TimeSlowSpell)
                Utility.Wait(1.2)
                
                PlayerRef.RemoveSpell(ParryAttackDamage)
                PlayerRef.RemoveSpell(DamageImmunity)
                PlayerRef.RemovePerk(StaggerResistance)

                Utility.Wait(0.1)
                ParryHit.SetValue(0)
            endif
        else
            Debug.SendAnimationEvent(ParryActor, "recoilStart")
        endif
    endif
EndEvent


;==========================
; 🔍 전투 중인 적 탐색 | Search for enemies in battle
;==========================
Function FindAndTrackEnemy()
    Actor ClosestEnemy = PlayerRef.GetCombatTarget() as Actor

    if ClosestEnemy && ClosestEnemy.IsHostileToActor(PlayerRef)
        if ClosestEnemy != LastAggressor
            if LastAggressor
                UnregisterForAnimationEvent(LastAggressor, "HitFrame")
            endif
            LastAggressor = ClosestEnemy
            RegisterForAnimationEvent(ClosestEnemy, "HitFrame")
        endif
    else
        if LastAggressor
            UnregisterForAnimationEvent(LastAggressor, "HitFrame")
            LastAggressor = None
        endif
    endif
EndFunction
