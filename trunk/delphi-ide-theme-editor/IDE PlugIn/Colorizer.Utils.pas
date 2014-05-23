//**************************************************************************************************
//
// Unit Colorizer.Utils
// unit Colorizer.Utils for the Delphi IDE Colorizer
//
// The contents of this file are subject to the Mozilla Public License Version 1.1 (the "License");
// you may not use this file except in compliance with the License. You may obtain a copy of the
// License at http://www.mozilla.org/MPL/
//
// Software distributed under the License is distributed on an "AS IS" basis, WITHOUT WARRANTY OF
// ANY KIND, either express or implied. See the License for the specific language governing rights
// and limitations under the License.
//
// The Original Code is Colorizer.Utils.pas.
//
// The Initial Developer of the Original Code is Rodrigo Ruz V.
// Portions created by Rodrigo Ruz V. are Copyright (C) 2011-2014 Rodrigo Ruz V.
// All Rights Reserved.
//
//**************************************************************************************************

unit Colorizer.Utils;

interface

{$I ..\Common\Jedi.inc}

uses
 {$IFDEF DELPHIXE2_UP}
 VCL.Themes,
 VCL.Styles,
 {$ENDIF}
 Classes,
 {$IFDEF DELPHI2009_UP}
 Generics.Collections,
 {$ENDIF}
 ActnMan,
 ComCtrls,
 uDelphiVersions,
 ActnColorMaps,
 Windows,
 PngImage,
 Graphics,
 Colorizer.Settings,
 ColorXPStyleActnCtrls;

{$DEFINE ENABLELOG}

procedure AddLog(const Message : string); overload;
procedure AddLog(const Category, Message : string); overload;

procedure RefreshIDETheme(AColorMap:TCustomActionBarColorMap;AStyle: TActionBarStyle;Restore : Boolean = False;Invalidate : Boolean = False); overload;
procedure RefreshIDETheme(Invalidate : Boolean = False); overload;
procedure RestoreIDESettings();

procedure LoadSettings(AColorMap:TCustomActionBarColorMap; Settings : TSettings);
procedure ProcessComponent(AColorMap:TCustomActionBarColorMap;AStyle: TActionBarStyle;AComponent: TComponent;Restore : Boolean = False; Invalidate : Boolean = False);
procedure GenerateColorMap(AColorMap:TCustomActionBarColorMap;Color, FontColor:TColor);{$IF CompilerVersion >= 23}overload;{$IFEND}
{$IFDEF DELPHIXE2_UP}
procedure GenerateColorMap(AColorMap:TCustomActionBarColorMap;Style:TCustomStyleServices);overload;
procedure RegisterVClStylesFiles;
{$ENDIF}


 type
   TColorizerLocalSettings = class
   public
      {$IFDEF DELPHI2009_UP}
      class var ActnStyleList : TList<TActionManager>;
      {$ENDIF}
      class var ColorMap       : TCustomActionBarColorMap;
      class var ActionBarStyle : TActionBarStyle;
      class var HookedWindows     : TStringList;
      class var HookedScrollBars  : TStringList;
      class var HookedWindowsText    : string;
      class var HookedScrollBarsText  : string;
      class var VCLStylesPath  : string;
      class var Settings       : TSettings;
      class var ImagesGutterChanged : Boolean;
      class var IDEData        : TDelphiVersionData;
      class var DockImages     : TPngImage;
    end;

implementation

{.$DEFINE DEBUG_MODE}

uses
 {$IFDEF DELPHIXE_UP}
 PlatformDefaultStyleActnCtrls,
 {$ELSE}
 XPStyleActnCtrls,
 {$ENDIF}
 {$IFDEF DELPHI2010_UP}
 Rtti,
 {$ENDIF}
 Types,
 IOUtils,
{$IFDEF ENABLELOG}
{$ENDIF}
 Forms,
 SysUtils,
 Controls,
 GraphUtil,
 Colorizer.StoreColorMap,
 Colorizer.Wrappers,
 Dialogs,
 uMisc,
 uRttiHelper;

{$IFDEF ENABLELOG}
var
  LogFile : TStrings = nil;
{$ENDIF}

//var
//  LFieldsComponents : TObjectDictionary<string,TStringList>;

{$IFDEF DELPHIXE2_UP}
procedure RegisterVClStylesFiles;
var
 sPath, FileName : string;
begin
  sPath:=TColorizerLocalSettings.VCLStylesPath;
  if SysUtils.DirectoryExists(sPath) then
  for FileName in TDirectory.GetFiles(sPath, '*.vsf') do
   if TStyleManager.IsValidStyle(FileName) then
    begin
       try
         TStyleManager.LoadFromFile(FileName);
       except
         on EDuplicateStyleException do
       end;
    end;
end;
{$ENDIF}


procedure AddLog(const Category, Message : string);
begin
{$IFDEF ENABLELOG}
   TFile.AppendAllText('C:\Delphi\google-code\DITE\delphi-ide-theme-editor\IDE PlugIn\log.txt',Format('%s %s : %s %s',[FormatDateTime('hh:nn:ss.zzz', Now), Category, Message, sLineBreak]));
//   if not Assigned(LogFile) then exit;
//
//   if Category<>'' then
//    LogFile.Add(Format('%s : %s', [Category, Message]))
//   else
//    LogFile.Add(Format('%s', [Message]));
{$ENDIF}
end;

procedure AddLog(const Message : string);
begin
  AddLog('', Message);
end;


procedure RefreshIDETheme(Invalidate : Boolean = False);
begin
   RefreshIDETheme(TColorizerLocalSettings.ColorMap, TColorizerLocalSettings.ActionBarStyle, False, Invalidate);
end;

procedure RefreshIDETheme(AColorMap:TCustomActionBarColorMap;AStyle: TActionBarStyle;Restore : Boolean = False; Invalidate : Boolean = False);
var
  Index     : Integer;
begin
 {
  if GlobalSettings.EnableDWMColorization and DwmIsEnabled then
   SetCompositionColor(AColorMap.Color);
 }
  for Index := 0 to Screen.FormCount-1 do
  if TColorizerLocalSettings.HookedWindows.IndexOf(Screen.Forms[Index].ClassName)<>-1 then
  begin
   if not (csDesigning in Screen.Forms[Index].ComponentState) then
     ProcessComponent(AColorMap, AStyle, Screen.Forms[Index], Restore, Invalidate);
  end
//  {$IFDEF DELPHIXE2_UP}
//  else
//  if (TColorizerLocalSettings.Settings<>nil) and (TColorizerLocalSettings.Settings.UseVCLStyles) and (csDesigning in Screen.Forms[index].ComponentState) then
//    ApplyEmptyVCLStyleHook(Screen.Forms[index].ClassType);
//  {$ENDIF}
end;


procedure LoadSettings(AColorMap:TCustomActionBarColorMap; Settings : TSettings);
Var
 ThemeFileName : string;
begin
  if Settings=nil then exit;
  ReadSettings(Settings, ExtractFilePath(GetModuleLocation()));
  ThemeFileName:=IncludeTrailingPathDelimiter(ExtractFilePath(GetModuleLocation()))+'Themes\'+Settings.ThemeName+'.idetheme';
  if FileExists(ThemeFileName) then
   LoadColorMapFromXmlFile(AColorMap, ThemeFileName);

//  if ActionBarStyles.IndexOf(Settings.StyleBarName)>=0 then
//    ActionBarStyle:= TActionBarStyle(ActionBarStyles.Objects[ActionBarStyles.IndexOf(Settings.StyleBarName)]);
end;


procedure GenerateColorMap(AColorMap:TCustomActionBarColorMap;Color, FontColor:TColor);
begin
  AColorMap.Color                 :=Color;
  AColorMap.ShadowColor           :=GetShadowColor(Color);
  AColorMap.FontColor             :=FontColor;
  AColorMap.MenuColor             :=GetHighLightColor(Color);
  AColorMap.HighlightColor        :=GetHighLightColor(AColorMap.MenuColor);
  AColorMap.BtnSelectedColor      :=GetHighLightColor(AColorMap.MenuColor);
  AColorMap.BtnSelectedFont       :=AColorMap.FontColor;

  AColorMap.SelectedColor         :=GetHighLightColor(Color, 50);
  AColorMap.SelectedFontColor     :=AColorMap.FontColor;

  AColorMap.BtnFrameColor         :=GetShadowColor(Color);
  AColorMap.FrameTopLeftInner     :=GetShadowColor(Color);
  AColorMap.FrameTopLeftOuter     :=AColorMap.FrameTopLeftInner;
  AColorMap.FrameBottomRightInner :=AColorMap.FrameTopLeftInner;
  AColorMap.FrameBottomRightOuter :=AColorMap.FrameTopLeftInner;
end;

{$IFDEF DELPHIXE2_UP}
procedure GenerateColorMap(AColorMap:TCustomActionBarColorMap;Style:TCustomStyleServices);
begin
  AColorMap.Color                 :=Style.GetStyleColor(scPanel);
  AColorMap.ShadowColor           :=StyleServices.GetSystemColor(clBtnShadow);
  AColorMap.FontColor             :=Style.GetStyleFontColor(sfButtonTextNormal);

  AColorMap.MenuColor             :=Style.GetStyleColor(scWindow);
  AColorMap.HighlightColor        :=StyleServices.GetSystemColor(clHighlight);
  AColorMap.BtnSelectedColor      :=Style.GetStyleColor(scButtonHot);

  AColorMap.BtnSelectedFont       :=StyleServices.GetSystemColor(clHighlightText);

  AColorMap.SelectedColor         :=StyleServices.GetSystemColor(clHighlight);
  AColorMap.SelectedFontColor     :=StyleServices.GetSystemColor(clHighlightText);

  AColorMap.BtnFrameColor         :=StyleServices.GetSystemColor(clBtnShadow);

  AColorMap.FrameTopLeftInner     :=StyleServices.GetSystemColor(clBtnShadow);
  AColorMap.FrameTopLeftOuter     :=AColorMap.FrameTopLeftInner;
  AColorMap.FrameBottomRightInner :=AColorMap.FrameTopLeftInner;
  AColorMap.FrameBottomRightOuter :=AColorMap.FrameTopLeftInner;
end;
{$ENDIF}

procedure ProcessComponent(AColorMap:TCustomActionBarColorMap;AStyle: TActionBarStyle;AComponent: TComponent;Restore : Boolean = False; Invalidate: Boolean = False);
var
  Index          : Integer;
  LActionManager : TActionManager;
//  LStrings       : TStringList;
  LForm          : TForm;
//  LToolbar       : TToolBar;
//  s              : string;
//  ctx            : TRttiContext;
//  LField         : TRttiField;
//  found          : Boolean;
begin
    if not Assigned(AComponent) or not Assigned(AColorMap) then  exit;

    if AComponent is TForm then
    begin
      LForm:=TForm(AComponent);
      LForm.Color := AColorMap.Color;
      LForm.Font.Color:=AColorMap.FontColor;

//      if SameText(LForm.ClassName, 'TProjectManagerForm') then
//      begin
//
//        LToolbar := TToolBar(LForm.FindComponent('ToolBar'));
//        if LToolbar<>nil then
//          LToolbar.
////          for Index := 0 to AComponent.ComponentCount - 1 do
////            if AComponent.Components[Index].GetParentComponent = LToolbar   then
////               AddLog('Toolbar ', AComponent.Components[Index].Name);
//      end;

      {
18:54:57.552 Toolbar  : tbProjectList
18:54:57.554 Toolbar  : ToolButton1
18:54:57.559 Toolbar  : ToolButton9
18:54:57.561 Toolbar  : ToolButton2
18:54:57.563 Toolbar  : ToolButton3
18:54:57.565 Toolbar  : tbs1
18:54:57.567 Toolbar  : tbSync
18:54:57.569 Toolbar  : tbExpandAll
18:54:57.572 Toolbar  : tbCollapseAll
18:54:57.574 Toolbar  : ToolButton5
18:54:57.576 Toolbar  : ToolButton4
18:54:57.578 Toolbar  : ToolButton6
18:54:57.579 Toolbar  : ToolButton7
18:54:57.582 Toolbar  : bConfiguration
18:54:57.584 Toolbar  : bPlatform
18:54:57.824 Toolbar  : tbProjectList
18:54:57.827 Toolbar  : ToolButton1
18:54:57.829 Toolbar  : ToolButton9
18:54:57.832 Toolbar  : ToolButton2
18:54:57.836 Toolbar  : ToolButton3
18:54:57.839 Toolbar  : tbs1
18:54:57.841 Toolbar  : tbSync
18:54:57.842 Toolbar  : tbExpandAll
18:54:57.844 Toolbar  : tbCollapseAll
18:54:57.846 Toolbar  : ToolButton5
18:54:57.849 Toolbar  : ToolButton4
18:54:57.851 Toolbar  : ToolButton6
18:54:57.852 Toolbar  : ToolButton7
18:54:57.854 Toolbar  : bConfiguration
18:54:57.856 Toolbar  : bPlatform
18:54:57.917 Toolbar  : tbProjectList
18:54:57.920 Toolbar  : ToolButton1
18:54:57.925 Toolbar  : ToolButton9
18:54:57.928 Toolbar  : ToolButton2
18:54:57.930 Toolbar  : ToolButton3
18:54:57.933 Toolbar  : tbs1
18:54:57.935 Toolbar  : tbSync
18:54:57.937 Toolbar  : tbExpandAll
18:54:57.939 Toolbar  : tbCollapseAll
18:54:57.940 Toolbar  : ToolButton5
18:54:57.943 Toolbar  : ToolButton4
18:54:57.944 Toolbar  : ToolButton6
18:54:57.946 Toolbar  : ToolButton7
18:54:57.948 Toolbar  : bConfiguration
18:54:57.950 Toolbar  : bPlatform
      }

      //process field TComponent no registered in the components list
//      ctx:=TRttiContext.Create;
//      try
//        if LFieldsComponents.ContainsKey(LForm.ClassName) then
//        begin
//          for s in LFieldsComponents.Items[LForm.ClassName] do
//          begin
//            LField:=ctx.GetType(LForm.ClassInfo).GetField(s);
//            if (LField.GetValue(LForm).AsObject<>nil) then
//             RunWrapper(TComponent(LField.GetValue(LForm).AsObject), AColorMap, Invalidate);
//          end;
//        end
//        else
//        begin
//
//          LStrings:= TStringList.Create;
//          LFieldsComponents.Add(LForm.ClassName, LStrings);
//          for LField in ctx.GetType(LForm.ClassInfo).GetFields() do
//             if LField.FieldType.IsInstance and (LField.GetValue(LForm).AsObject<>nil) and (LField.GetValue(LForm).AsObject is TComponent) and (TRegisteredWrappers.Wrappers.ContainsKey(LField.GetValue(LForm).AsObject.ClassName)) then
//             begin
//               found:=false;
//               for Index := 0 to LForm.ComponentCount - 1 do
//                 if SameText(LForm.Components[Index].Name, LField.Name) then
//                 begin
//                   found:=True;
//                   break;
//                 end;
//
//               if not found then
//                 LStrings.Add(LField.Name);
//             end;
//
//          for s in LStrings do
//            RunWrapper(TComponent(TRttiUtils.GetRttiFieldValue(LForm, s).AsObject), AColorMap, Invalidate);
//
////           if LStrings.Count>0 then
////            ShowMessage(LStrings.Text);
//        end;
//      finally
//        ctx.Free;
//      end;


      {
      if SameText(LForm.ClassName, 'TToolForm') then
        TRttiUtils.DumpObject(TRttiUtils.GetRttiFieldValue(LForm, 'FCategoriesPopup').AsObject,'C:\Delphi\google-code\DITE\delphi-ide-theme-editor\IDE PlugIn\Galileo\TCategoriesPopup.pas');
      }

      if Invalidate then
        LForm.Invalidate;
    end
    else
    if AComponent is TActionManager then
    begin
      LActionManager:=TActionManager(AComponent);
      {$IFDEF DELPHI2009_UP}
//      if not ActnStyleList.ContainsKey(LActionManager) then
//          ActnStyleList.Add(LActionManager, LActionManager.Style);
      if TColorizerLocalSettings.ActnStyleList.IndexOf(LActionManager)=-1 then
          TColorizerLocalSettings.ActnStyleList.Add(LActionManager);
      {$ENDIF}
      LActionManager.Style := AStyle;
    end
    else
    if AComponent is TFrame then
    with TFrame(AComponent) do
    begin
      Color := AColorMap.Color;
      Font.Color:=AColorMap.FontColor;
    end;

    RunWrapper(AComponent, AColorMap, Invalidate);

    //process components
    for Index := 0 to AComponent.ComponentCount - 1 do
     ProcessComponent(AColorMap, AStyle, AComponent.Components[Index], Restore);

    //process dock clients
    if AComponent is TWinControl then
     for Index := 0 to TWinControl(AComponent).DockClientCount - 1 do
     if TWinControl(AComponent).DockClients[Index].Visible and (TColorizerLocalSettings.HookedWindows.IndexOf(TWinControl(AComponent).DockClients[Index].ClassName)>=0) then
     begin
       //AddLog('DockClients '+TWinControl(AComponent).DockClients[Index].ClassName);
       ProcessComponent(AColorMap, AStyle, TWinControl(AComponent).DockClients[Index]);
       if Invalidate and  (TWinControl(AComponent).DockClients[Index] is TForm) then
        TWinControl(AComponent).DockClients[Index].Invalidate();
     end;
end;

procedure RestoreActnManagerStyles;
{$IFNDEF DLLWIZARD}
var
  LActionManager : TActionManager;
{$ENDIF}
begin
{$IFNDEF DLLWIZARD}
 {$IFDEF DELPHI2009_UP}
  try
    if (TColorizerLocalSettings.ActnStyleList.Count>0)  and Assigned(ActionBarStyles) then
    begin
      for LActionManager in TColorizerLocalSettings.ActnStyleList{.Keys} do
      begin
         //LActionManager.Style:= ActnStyleList.Items[LActionManager];//ActionBarStyles.Style[ActionBarStyles.IndexOf(DefaultActnBarStyle)];
        if ActionBarStyles.IndexOf(DefaultActnBarStyle)>=0 then
        begin
         if Assigned(LActionManager.Style) and Assigned(ActionBarStyles.Style[ActionBarStyles.IndexOf(DefaultActnBarStyle)]) then
         begin
           //AddLog('ActionBarStyles '+ActionBarStyles.Style[ActionBarStyles.IndexOf(DefaultActnBarStyle)].GetStyleName);
           LActionManager.Style:= ActionBarStyles.Style[ActionBarStyles.IndexOf(DefaultActnBarStyle)];
         end;
        end;
      end;
    end;
  except on e: exception do //sometimes the references to the objects contained in ActionBarStyles are lost when the IDE is closed.
    AddLog(Format(' LActionManager.Style exception RestoreActnManagerStyles Message %s Trace %s ',[e.Message, e.StackTrace]));
  end;
 {$ELSE DELPHI2009_UP}
   //TODO
 {$ENDIF}

{$ENDIF}
end;

procedure RestoreIDESettings();
var
 NativeColorMap : TCustomActionBarColorMap;
begin
{$IFDEF DELPHIXE2_UP}
  if TColorizerLocalSettings.Settings.UseVCLStyles then
    if not TStyleManager.ActiveStyle.IsSystemStyle  then
     TStyleManager.SetStyle('Windows');
{$ENDIF}

{$IFDEF DELPHIXE_UP}
  NativeColorMap:=TThemedColorMap.Create(nil);
{$ELSE}
  NativeColorMap:=TStandardColorMap.Create(nil);
{$ENDIF}

  try
  {$IFDEF DELPHIXE_UP}
    RefreshIDETheme(NativeColorMap, PlatformDefaultStyle, True);
  {$ELSE}
    RefreshIDETheme(NativeColorMap, XPStyle, True);
  {$ENDIF}
  finally
    NativeColorMap.Free;
  end;
  RestoreActnManagerStyles();
end;

initialization

{$IFDEF ENABLELOG}
 LogFile:=TStringList.Create;
 ShowMessage('Log enabled');
{$ENDIF}
 //LFieldsComponents := TObjectDictionary<string,TStringList>.Create([doOwnsValues]);
finalization
{$IFDEF ENABLELOG}
  LogFile.SaveToFile('C:\Delphi\google-code\DITE\delphi-ide-theme-editor\IDE PlugIn\log.txt');
  LogFile.Free;;
{$ENDIF}
 //LFieldsComponents.Free;
end.