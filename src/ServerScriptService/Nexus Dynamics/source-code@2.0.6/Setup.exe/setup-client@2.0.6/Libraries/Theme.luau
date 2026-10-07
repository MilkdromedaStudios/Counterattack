----- || TYPE CHECK || -----
type Accent = ("--Accent") -> Color3
type Error = ("--Error") -> Color3
type Warning = ("--Warning") -> Color3
type Background = ("--Background") -> Color3
type TopBackground = ("--Top-Background") -> Color3
type TopBorder = ("--Top-Border") -> Color3
type RibbonBackground = ("--Ribbon-Background") -> Color3
type RibbonBorder = ("--Ribbon-Border") -> Color3
type BottomBackground = ("--Bottom-Background") -> Color3
type BottomBorder = ("--Bottom-Border") -> Color3
type Close = ("--Close") -> Color3
type SidebarBackground = ("--Sidebar-Background") -> Color3
type SidebarButtonOdd = ("--Sidebar-Button-Odd") -> Color3
type SidebarButtonEven = ("--Sidebar-Button-Even") -> Color3
type SidebarIcon = ("--Sidebar-Icon") -> Color3
type SidebarIconActive = ("--Sidebar-Icon-Active") -> Color3
type SidebarText = ("--Sidebar-Text") -> Color3
type SidebarTextActive = ("--Sidebar-Text-Active") -> Color3
type SidebarButtonActive = ("--Sidebar-Button-Active") -> Color3
type TitleBackground = ("--Title-Background") -> Color3
type PrimaryTextColor = ("--Primary-Text-Color") -> Color3
type ButtonBackground = ("--Button-Background") -> Color3
type Shadow = ("--Shadow") -> Color3
type ToggleHeadOff = ("--Toggle-Head-Off") -> Color3
type ToggleHeadOn = ("--Toggle-Head-On") -> Color3
type ToggleBackgroundOff = ("--Toggle-Background-Off") -> Color3
type ToggleBackgroundOn = ("--Toggle-Background-On") -> Color3
type OptionSelected = ("--Option-Selected") -> Color3
type SliderHead = ("--Slider-Head") -> Color3
type SliderBackground = ("--Slider-Background") -> Color3
type SliderFiller = ("--Slider-Filler") -> Color3
type DefaultAccount = ("--Default-Account") -> Color3
type Border = ("--Border") -> Color3
type ScrollBar = ("--ScrollBar") -> Color3 
type AccentTextColor = ("--Accent-Text-Color") -> Color3 
type ProfileBackground = ("--Profile-Background") -> Color3 
type SkyboxIndexBackground = ("--Skybox-Index-Background") -> Color3 
type ButtonBorder = ("--Button-Border") -> Color3
type DescriptionTexteColor = ("--Description-Text-Color") -> Color3
type SecondaryTextColor = ("--Secondary-Text-Color") -> Color3
type TabBackground = ("--Tab-Background") -> Color3 
type TabBackgroundActive = ("--Tab-Background-Active") -> Color3
type TabBorder = ("--Tab-Border") -> Color3 
type AccountTabBackground = ("--AccountTab-Background") -> Color3 
type AccountTabBackgroundActive = ("--AccountTab-Background-Active") -> Color3 
type AccountTabBorder = ("--AccountTab-Border") -> Color3 
type DropdownBackground = ("--Dropdown-Background") -> Color3 
type DropdownBorder = ("--Dropdown-Border") -> Color3 
type TextBoxBackground = ("--TextBox-Background") -> Color3 
type TextBoxBorder = ("--TextBox-Border") -> Color3
type ButtonTextColor = ("--Button-Text-Color") -> Color3
type DropdownTextColor = ("--Dropdown-Text-Color") -> Color3
type TextBoxTextColor = ("--TextBox-Text-Color") -> Color3
type TextBoxPlaceholderColor = ("--TextBox-Placeholder-Color") -> Color3
type SliderTextColor = ("--Slider-Text-Color") -> Color3
type TabTextColor = ("--Tab-Text-Color") -> Color3
type TabIconColor = ("--Tab-Icon-Color") -> Color3
type AccountTabTextColor = ("--AccountTab-Text-Color") -> Color3
type AccountTabIconColor = ("--AccountTab-Icon-Color") -> Color3
type ProfileCardColor = ("--Profile-Card-Color") -> Color3
type ClockTextColor = ("--Clock-Text-Color") -> Color3
type TabBackgroundHover = ("--Tab-Background-Hover") -> Color3
type AccountTabBackgroundHover = ("--AccountTab-Background-Hover") -> Color3
type Tint = ("--Tint") -> Color3

type colors = Tint & TabBackgroundHover & AccountTabBackgroundHover & ClockTextColor & ButtonTextColor & DropdownTextColor & TextBoxTextColor & TextBoxPlaceholderColor & SliderTextColor & TabTextColor & TabIconColor & AccountTabTextColor & AccountTabIconColor & ProfileCardColor & RibbonBorder & TopBorder & BottomBorder & TabBackground & TabBackgroundActive & TabBorder & AccountTabBackground & AccountTabBackgroundActive & AccountTabBorder & DropdownBackground & DropdownBorder & TextBoxBackground & TextBoxBorder & DescriptionTexteColor & SecondaryTextColor & ButtonBorder & AccentTextColor & ProfileBackground & SkyboxIndexBackground & Accent & Error & Warning & Background & TopBackground & RibbonBackground & BottomBackground & Close & SidebarBackground & SidebarButtonOdd & SidebarButtonEven & TitleBackground & PrimaryTextColor & ButtonBackground & Shadow & ToggleHeadOff & ToggleHeadOn & ToggleBackgroundOff & ToggleBackgroundOn & OptionSelected & SliderHead & SliderBackground & SliderFiller & DefaultAccount & Border & ScrollBar & SidebarIcon & SidebarText & SidebarIconActive & SidebarTextActive & SidebarButtonActive



----- || MAIN || -----
return function( name )	
	local _dict = {
		
		["--Tint"] = Color3.fromRGB(255, 255, 255),
		["--Accent"] = Color3.fromRGB(48, 176, 255),

		["--Error"] = Color3.fromRGB(255, 42, 42),
		["--Warning"] = Color3.fromRGB(255, 185, 21),

		["--Background"] = Color3.fromRGB(15, 15, 19),
		["--Top-Background"] = Color3.fromRGB(22, 22, 26),
		["--Top-Border"] = Color3.fromRGB(33, 33, 37),
		["--Ribbon-Background"] = Color3.fromRGB(19, 19, 23),
		["--Ribbon-Border"] = Color3.fromRGB(33, 33, 37),
		["--Bottom-Background"] = Color3.fromRGB(22, 22, 26), 
		["--Bottom-Border"] = Color3.fromRGB(33, 33, 37),
		
		["--Close"] = Color3.fromRGB(255, 42, 42),
		["--Clock-Text-Color"] = Color3.fromRGB(127, 127, 127),
		
		["--Sidebar-Background"] = Color3.fromRGB(22, 22, 26),
		["--Sidebar-Button-Odd"] = Color3.fromRGB(22, 22, 26),
		["--Sidebar-Button-Even"] = Color3.fromRGB(17, 17, 21),
		["--Sidebar-Button-Active"] = Color3.fromRGB(16, 56, 80),
		["--Sidebar-Icon"] = Color3.fromRGB(255, 255, 255),
		["--Sidebar-Icon-Active"] = Color3.fromRGB(255, 255, 255),
		["--Sidebar-Text"] = Color3.fromRGB(255, 255, 255),
		["--Sidebar-Text-Active"] = Color3.fromRGB(255, 255, 255),

		["--Title-Background"] = Color3.fromRGB(19, 19, 23),
		["--Profile-Background"] = Color3.fromRGB(0, 0, 0),
		["--Skybox-Index-Background"] = Color3.fromRGB(0, 0, 0),
		
		["--Primary-Text-Color"] = Color3.fromRGB(215, 215, 215),
		["--Secondary-Text-Color"] = Color3.fromRGB(148, 148, 154),
		["--Accent-Text-Color"] = Color3.fromRGB(0, 0, 0),
		["--Description-Text-Color"] = Color3.fromRGB(148, 148, 154),
		
		["--Button-Background"] = Color3.fromRGB(22, 22, 26),
		["--Button-Border"] = Color3.fromRGB(33, 33, 37),
		["--Shadow"] = Color3.fromRGB(0, 0, 0),

		["--Toggle-Head-Off"] = Color3.fromRGB(255, 255, 255),
		["--Toggle-Head-On"] = Color3.fromRGB(48, 176, 255),
		["--Toggle-Background-Off"] = Color3.fromRGB(108, 108, 111), 
		["--Toggle-Background-On"] = Color3.fromRGB(27, 78, 111),

		["--Option-Selected"] = Color3.fromRGB(41, 41, 48),

		["--Slider-Head"] = Color3.fromRGB(255, 255, 255), 
		["--Slider-Background"] = Color3.fromRGB(42, 42, 49),
		["--Slider-Filler"] = Color3.fromRGB(108, 108, 111),

		["--Default-Account"] = Color3.fromRGB(108, 108, 111), 

		["--Border"] = Color3.fromRGB(33, 33, 37),
		["--ScrollBar"] = Color3.fromRGB(114, 114, 145), 
		
		["--Tab-Background"] = Color3.fromRGB(16, 16, 20), 
		["--Tab-Background-Active"] = Color3.fromRGB(28, 28, 32),
		["--Tab-Background-Hover"] = Color3.fromRGB(28, 28, 32),
		["--Tab-Border"] = Color3.fromRGB(16, 16, 20), 
		["--AccountTab-Background"] = Color3.fromRGB(22, 22, 26), 
		["--AccountTab-Background-Active"] = Color3.fromRGB(43, 43, 50),
		["--AccountTab-Background-Hover"] = Color3.fromRGB(43, 43, 50),
		["--AccountTab-Border"] = Color3.fromRGB(33, 33, 37), 
		["--Dropdown-Background"] = Color3.fromRGB(22, 22, 26), 
		["--Dropdown-Border"] = Color3.fromRGB(33, 33, 37), 
		["--TextBox-Background"] = Color3.fromRGB(22, 22, 26), 
		["--TextBox-Border"] = Color3.fromRGB(33, 33, 37),
		
		["--Button-Text-Color"] = Color3.fromRGB(215, 215, 215),
		["--Dropdown-Text-Color"] = Color3.fromRGB(215, 215, 215),
		["--TextBox-Text-Color"] = Color3.fromRGB(215, 215, 215),
		["--TextBox-Placeholder-Color"] = Color3.fromRGB(148, 148, 154),
		["--Slider-Text-Color"] = Color3.fromRGB(215, 215, 215),
		["--Tab-Text-Color"] = Color3.fromRGB(215, 215, 215),
		["--Tab-Icon-Color"] = Color3.fromRGB(215, 215, 215),
		["--AccountTab-Text-Color"] = Color3.fromRGB(215, 215, 215),
		["--AccountTab-Icon-Color"] = Color3.fromRGB(215, 215, 215),
		["--Profile-Card-Color"] = Color3.fromRGB(76, 77, 86),
	}
	
	return _G["setup-client@2.0.6\colors"][name] or _dict[name]	
end :: colors
