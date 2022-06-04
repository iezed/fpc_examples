Unit uJSON;

{$MODE objfpc}{$H+}

Interface

(*
 * Historie: 0.01 = Initial version
 *           0.02 = In Array's erlauben, dass anstatt eines Nodes auch einfach nur ein String steht
 *           0.03 = TJSONArray.clear
 *           0.04 = Fix Parsing Error, Array of Array
 *           0.05 = FindPath
 *           0.06 = Abstieg in ArrayElemente in Findpath ging nicht
 *           0.07 = Optional // und /* */ Kommentare wie in JSON5
 *           0.08 = Uncommenter unterstützt nun StringLiterale -> Besserer Support für JSON5 Kommentare
 *           0.09 = Array Parsing erlaubte "zu viel" ungültiges -> Parser Verschärft
 *           0.10 = Einführen des Feldes "Tag"
 *
 * Known Bugs: Wenn der zu Parsende Text kein Gültiges JSON ist, entstehen Speicherlöcher !
 *)

(*
 * Den untenstehenden Text auf
 *
 * http://plantuml.com/
 *
 * einfügen und man bekommt ein Klassendiagram

 @startuml

 abstract class TJSONobj {
 {abstract} +String ToString()
 {abstract} +TJSONobj FindPath(String)
 }

 class TJSONArray {
 + integer ObjCount
 + TJSONobj Obj[Integer]
 + AddObj(TJSONobj)
 + Clear()
 + String ToString()
 }

 class TJSONNode {
 + integer ObjCount
 + TJSONobj Obj[Integer]
 + AddObj(TJSONobj)
 + String ToString()
 }

 class TJSONNodeObj{
 +String Name
 +TJSONobj Value
 +String ToString()
 }

 class TJSONValue{
 +String Name
 +String Value
 +String ToString()
 }

 class TJSONTerminal{
 +String Value
 +String ToString()
 }

 class TJSONParser{
 +jsonobj Parse(String)
 }

 '\Ableitungshierarchieen \'

 TJSONArray --|> TJSONobj
 TJSONNode --|> TJSONobj
 TJSONNodeObj--|> TJSONobj
 TJSONValue --|> TJSONobj
 TJSONTerminal--|> TJSONobj

 '\Die ganzen enthält Beziehungen \'

 TJSONArray *-- TJSONobj
 TJSONNode *-- TJSONobj
 TJSONNodeObj *-- TJSONobj

 TJSONParser*-- TJSONobj

 @enduml

 *)

Const
  SpaceIdent = '  '; // Einrückung pro Schachtelungstiefe

Type

  { TJSONObj }

  TJSONObj = Class // Basisklasse für alle JSON Objekte
  private
    fName: String;
    fobjs: Array Of TJSONObj;
  protected
    Procedure Clear; virtual;
  public
    Tag: PtrInt; // For the User, is not needed by the JSON Library = 0 on Create
    Constructor Create; virtual;
    Destructor Destroy; override;

    Function ToString(FrontSpace: String = ''): String; virtual; reintroduce; // Abstract;
    Function FindPath(APath: String): TJSONObj; virtual; // Abstract;
  End;

  { TJSONArray }

  TJSONArray = Class(TJSONObj)
  private
    Function getObjCount: integer;
    Function getObj(index: integer): TJSONObj;

  public

    Property ObjCount: integer read getObjCount;
    Property Obj[Index: integer]: TJSONObj read getObj;

    Constructor Create; override;

    Procedure AddObj(JSONObj: TJSONObj);
    Procedure Clear; override;

    Function ToString(FrontSpace: String = ''): String; override;
  End;

  { TJSONNode }

  TJSONNode = Class(TJSONObj)
  private
    Function getObjCount: integer;
    Function getObj(index: integer): TJSONObj;
  public
    Property ObjCount: integer read getObjCount;
    Property Obj[Index: integer]: TJSONObj read getObj;

    Constructor Create; override;

    Procedure AddObj(JSONObj: TJSONObj);
    Procedure Clear; override;

    Function ToString(FrontSpace: String = ''): String; override;
  End;

  { TJSONNodeObj }

  TJSONNodeObj = Class(TJSONObj)
  private
    fvalue: TJSONObj;
  public
    Property Name: String read fName;
    Property Value: TJSONObj read fvalue;

    Constructor Create(aName: String; aValue: TJSONObj); reintroduce;
    Destructor Destroy; override;

    Function ToString(FrontSpace: String = ''): String; override;
    Function FindPath(APath: String): TJSONObj; override;

  End;

  { TJSONValue }

  TJSONValue = Class(TJSONObj)
  private
    fvalue: String;
    fvalueIsString: Boolean;
  public
    Property Name: String read fName;
    Property Value: String read fvalue;

    Constructor Create(aName, aValue: String; ValueisString: Boolean); reintroduce;

    Function ToString(FrontSpace: String = ''): String; override;
  End;

  { TJSONTerminal }

  TJSONTerminal = Class(TJSONObj)
  private
    fIsString: Boolean;
  public
    Property Value: String read fName write fName;
    Property IsString: Boolean read fIsString write fIsString;

    Constructor Create(aValue: String); reintroduce;

    Function ToString(FrontSpace: String = ''): String; override;
  End;

  { TJSONParser }

  TJSONParser = Class
  private
    fparsedata: String;
    fparsedataptr: integer;

    Function NextToken(EatToken: Boolean): String;
    Procedure Eat(Token: String);

    Function ParseHelper(): TJSONObj;
    Function ParseNode(): TJSONNode;
    Function ParseString(): TJSONTerminal;
    Function ParseArray(): TJSONArray;

  public
    SupportJSON5Comments: Boolean; // Wenn True [default=false], dann wird JSON5 Like ein Unkommenting vor dem Parsen gemacht.
    Constructor Create;
    Destructor Destroy; override;

    (*
     * Parst den Text gemäß:
     *   https://www.json.org/json-en.html
     *  Zusätzlich unterstützt der Parser die aus JSON5 bekannten Commentar Strukturen
     *  // -- Einzeilen Kommentare
     *  /* -- Multi Zeilen Kommentare */
     *)
    Function Parse(Data: String): TJSONObj;
  End;

Function StringToJsonString(Data: String): String;

Implementation

Uses sysutils, uncommenter;

Procedure Nop;
Begin

End;

Function StringToJsonString(Data: String): String;
Begin
  (*
   * Konvertiert einen string in einen JSON String, durch geeignetes ersetzen der
   * nicht erlaubten Zeichen
   *
   * " Double quote
   * \ Backslash character
   * / solidor
   * \b Backspace (ascii code 08)
   * \f Form feed (ascii code 0C)
   * \n New line
   * \r Carriage return
   * \t Tab
   * \u4 hexadecimal digit -- Unicode Zeichen
   *)
  Data := StringReplace(Data, '\', '\\', [rfReplaceAll]);
  Data := StringReplace(Data, '"', '\"', [rfReplaceAll]);
  Data := StringReplace(Data, '/', '\/', [rfReplaceAll]);
  Data := StringReplace(Data, #8, '\b', [rfReplaceAll]);
  Data := StringReplace(Data, #13#10, '\r', [rfReplaceAll]);
  Data := StringReplace(Data, #13, '\f', [rfReplaceAll]);
  Data := StringReplace(Data, #10, '\n', [rfReplaceAll]);
  Data := StringReplace(Data, #9, '\t', [rfReplaceAll]);
  // TODO: Rauskriegen wie wir das mit UTF8 Zeichen machen ...
  result := '"' + Data + '"';
End;

{ TJSONTerminal }

Constructor TJSONTerminal.Create(aValue: String);
Begin
  Inherited create;
  fName := '';
  If length(aValue) > 1 Then Begin
    If (avalue[1] = '"') And (avalue[length(aValue)] = '"') Then Begin
      fName := copy(aValue, 2, length(aValue) - 2);
      fIsString := true;
    End
    Else Begin
      fName := aValue; // Eigentlich müsste hier ne AV kommen
      fIsString := false;
    End;
  End
  Else Begin
    fName := aValue; // Eigentlich müsste hier ne AV kommen
    fIsString := false;
  End;
End;

Function TJSONTerminal.ToString(FrontSpace: String): String;
Begin
  If fIsString Then Begin
    result := FrontSpace + StringToJsonString(fName);
  End
  Else Begin
    result := FrontSpace + fName;
  End;
End;

{ TJSONObj }

Procedure TJSONObj.Clear;
Var
  i: integer;
Begin
  For i := 0 To High(fobjs) Do
    fobjs[i].Free;
  setlength(fobjs, 0);
End;

Constructor TJSONObj.Create;
Begin
  Inherited Create;
  Tag := 0;
  fName := '';
  fobjs := Nil;
End;

Destructor TJSONObj.Destroy;
Begin
  Clear;
End;

Function TJSONObj.ToString(FrontSpace: String): String;
Begin
  result := '';
  Raise Exception.Create('ToString not implemented in ' + ClassName);
End;

Function TJSONObj.FindPath(APath: String): TJSONObj;
Var
  elem: String;
  i: Integer;
Begin
  result := Nil;
  If apath = '' Then Begin
    result := self;
    exit;
  End;
  elem := APath;
  APath := '';
  For i := 1 To length(elem) Do Begin
    If elem[i] = '.' Then Begin // Weiter Absteigen
      APath := copy(elem, i + 1, length(elem));
      elem := copy(elem, 1, i - 1);
      break;
    End;
    If elem[i] = '[' Then Begin // Zugriff auf Array Elemente
      APath := copy(elem, i, length(elem));
      elem := copy(elem, 1, i - 1);
      break;
    End;
  End;
  elem := LowerCase(elem);
  If (elem = '') And (pos('[', APath) = 1) Then Begin
    i := strtointdef(copy(APath, 2, pos(']', APath) - 2), -1);
    If (i <> -1) And (i <= high(fobjs)) Then Begin
      elem := copy(APath, pos(']', APath) + 1, length(APath));
      If (elem <> '') And (elem[1] = '.') Then Begin
        // Eigentlich muss beim Zugriff nach [] zwingend ein Punkt kommen,
        // so wäre er nur Optional, wenn man da mehr haben will..
        elem := copy(elem, 2, length(elem));
      End;
      result := fobjs[i].FindPath(elem);
      exit;
    End;
  End;
  For i := 0 To high(fobjs) Do Begin
    If lowercase(fobjs[i].fName) = elem Then Begin
      result := fobjs[i].FindPath(APath);
      exit;
    End;
  End;
End;

{ TJSONArray }

Constructor TJSONArray.Create;
Begin
  Inherited create;
  fobjs := Nil;
End;

Function TJSONArray.getObj(index: integer): TJSONObj;
Begin
  result := fobjs[Index];
End;

Function TJSONArray.getObjCount: integer;
Begin
  result := length(fobjs);
End;

Function TJSONArray.ToString(FrontSpace: String): String;
Var
  res: String;
  i: integer;
Begin
  res := LineEnding + FrontSpace + '[' + LineEnding;
  For i := 0 To High(fobjs) Do Begin
    If (i > 0) Then Begin
      res := res + ',' + LineEnding;
    End;
    res := res + fobjs[i].ToString(FrontSpace + SpaceIdent);
  End;
  result := res + LineEnding + FrontSpace + ']';
End;

Procedure TJSONArray.AddObj(JSONObj: TJSONObj);
Begin
  setlength(fobjs, High(fobjs) + 2);
  fobjs[High(fobjs)] := JSONObj;
End;

Procedure TJSONArray.Clear;
Begin
  Inherited Clear;
End;

{ TJSONNode }

Constructor TJSONNode.Create;
Begin
  Inherited create;
  fobjs := Nil;
End;

Function TJSONNode.getObj(index: integer): TJSONObj;
Begin
  result := fobjs[Index];
End;

Function TJSONNode.getObjCount: integer;
Begin
  result := length(fobjs);
End;

Function TJSONNode.ToString(FrontSpace: String): String;
Var
  res: String;
  i: integer;
Begin
  res := FrontSpace + '{' + LineEnding;
  For i := 0 To High(fobjs) Do Begin
    If (i > 0) Then Begin
      res := res + ',' + LineEnding;
    End;
    res := res + fobjs[i].ToString(FrontSpace + SpaceIdent);
  End;
  result := res + LineEnding + FrontSpace + '}';
End;

Procedure TJSONNode.AddObj(JSONObj: TJSONObj);
Begin
  setlength(fobjs, High(fobjs) + 2);
  fobjs[High(fobjs)] := JSONObj;
End;

Procedure TJSONNode.Clear;
Begin
  Inherited Clear;
End;

{ TJSONParser }

Constructor TJSONParser.Create;
Begin
  SupportJSON5Comments := false;
  Inherited Create;
End;

Destructor TJSONParser.Destroy;
Begin

End;

Procedure TJSONParser.Eat(Token: String);
Var
  atoken: String;
Begin
  atoken := NextToken(true);
  atoken := LowerCase(atoken);
  Token := LowerCase(Token);
  If (atoken <> Token) Then Begin
    nop;
    Raise Exception.Create('Expected token : "' + Token + '" got "' + atoken + '"');
  End;
End;

Function TJSONParser.NextToken(EatToken: Boolean): String;
(*
 * Der JSON Lexer, der einen String nach JSON Tokens separiert whitespace
 * zwischen den Tokens wird ignoriert.
 *)
Const
  tokens: Set Of char = ['[', ']', '{', '}', ':', ',']; // In JSON sind alle separierenden Tokens zum Glück 1 Byte groß ;)
Var
  aindex: integer;
  achar: char;
  inString, skipnext, ignorenext, interpretnext: Boolean;
  res: String;
Begin
  aindex := fparsedataptr + 1;
  If (aindex > length(fparsedata)) Then Begin // Wir haben über das Ende der Datei hinausgelesen
    result := '';
    exit;
  End;
  achar := fparsedata[aindex];
  skipnext := false; // Das nächste Zeichen wird nicht in res aufgenommen
  ignorenext := false; // Das nächste Zeichen wird nicht für die String Auswertung berücksichtigt.
  interpretnext := false; // Das nächste zeichen muss gemäß der \ regel ausgewertet werden.
  res := '';
  inString := false;
  // Wenn das erste zu lesende Zeichen direkt ein Separierendes Token ist
  If (achar In tokens) Then Begin
    If (EatToken) Then Begin
      fparsedataptr := aindex;
    End;
    result := achar;
    exit;
  End;
  // Weitersuchen, so lange bis wir einen Token finden oder der String zuende ist.
  // Ausnahme in Strings, werden Tokens ignoriert!
  While (((Not (achar In tokens)) Or (inString)) And (aindex < length(fparsedata))) Do Begin
    If ((achar = '"') And (Not ignorenext)) Then Begin
      inString := Not inString;
      skipnext := true;
      If (Not inString) Then Begin // Der String ist fertig, also ist das Token auch abgeschlossen
        If (EatToken) Then Begin
          fparsedataptr := aindex;
        End;
        result := res;
        exit;
      End;
    End;
    ignorenext := false;
    If (inString) Then Begin
      If (Not interpretnext) Then Begin
        If (achar = '\') Then Begin
          ignorenext := true;
          skipnext := true; // Das aktuell gelesene Zeichen ist ja ein Steuerzeichen, also nicht in den String übernehmen
          interpretnext := true;
        End;
      End
      Else Begin
        (*
         * " Double quote
         * \ Backslash character
         * / solidor
         * b Backspace (ascii code 08)
         * f Form feed (ascii code 0C)
         * n New line
         * r Carriage return
         * t Tab
         * u4 hexadecimal digit
         *)
        If (achar = 'b') Then achar := chr($08);
        If (achar = 'f') Then achar := chr($0C);
        If (achar = 'n') Then achar := chr($0A);
        If (achar = 'r') Then Begin
          res := res + chr($0C);
          achar := chr($0A);
        End;
        If (achar = 't') Then achar := chr($09);
        If (achar = 'u') Then Begin
          //todo: das Auswerten des Unicode Zeichens fehlt noch !!
          Raise Exception.Create('parser does not support \u symbols in string.');
        End;
        interpretnext := false;
      End;
      If (Not skipnext) Then Begin
        res := res + achar;
      End;
    End
    Else Begin
      If (ord(achar) > 32) Then Begin
        res := res + achar;
      End;
    End;
    skipnext := false;
    aindex := aindex + 1;
    achar := fparsedata[aindex];
  End;
  If (res = '') Then Begin // Wir haben nur Leerzeichen überlesen und eigentlich direkt wieder ein Token gelesen.
    If (EatToken) Then Begin
      fparsedataptr := aindex;
    End;
    result := achar;
    exit;
  End;
  If (EatToken) Then Begin // Wir haben ein Token gelesen und sind ja auf dem nächsten Stehen geblieben also eins weniger
    fparsedataptr := aindex - 1;
  End;
  result := res;
End;

Function TJSONParser.Parse(Data: String): TJSONObj;
Var
  Obj: TJSONObj;
  only_Space: Boolean;
  i: integer;
  uc: TUnCommenter;
Begin
  result := Nil;
  If SupportJSON5Comments Then Begin
    uc := TUnCommenter.Create;
    uc.AddRule('//', '', true);
    uc.AddRule('/*', '*/', False);
    uc.StringLiteral := '"';
{$IFDEF Windows}
    // Theoretisch könnte es sein das das Programm unter Windows läuft aber einen Linux CRT Bekommt,
    // Dann würde Lineweis nicht funktionieren, dafür bräuchte es dann ein Stringreplace .. das #10 in #13#10 umbaut
    // Unter Linux ist es egal, weil der JSON Parser alles < #32 eh weg wirft. und #10 in #13#10 enthalten ist.
    data := StringReplace(data, #10, LineEnding, [rfReplaceAll]);
{$ENDIF}
    data := uc.Uncomment(data);
    uc.free;
  End;
  fparsedata := Data;
  fparsedataptr := 0;
  Obj := ParseHelper();
  // Wenn nicht alles geparst wurde, dann schauen wir ob es sich nur noch um
  // Leerzeichen handelt die Fehlen oder ob echt Content fehlt.
  If (fparsedataptr <> length(fparsedata)) Then Begin
    only_Space := true;
    For i := fparsedataptr + 1 To length(fparsedata) Do Begin
      If (ord(fparsedata[i]) > 32) Then Begin
        only_Space := false;
        break;
      End;
    End;
    If (Not only_Space) Then Begin
      if assigned(obj) then obj.free;
      Raise Exception.Create('not all data where parsed, missing "' + copy(fparsedata, fparsedataptr + 1, length(fparsedata)) + '"');
    End;
  End;
  result := Obj;
End;

Function TJSONParser.ParseArray(): TJSONArray;
Var
  Obj: TJSONArray;
  ntoken: String;
Begin
  Obj := TJSONArray.Create;
  Eat('[');
  ntoken := NextToken(false);
  While ((ntoken <> '') And (ntoken <> ']')) Do Begin
    ntoken := NextToken(false);
    If ntoken = '{' Then Begin
      Obj.AddObj(ParseNode());
    End
    Else Begin
      If ntoken = '[' Then Begin
        obj.addobj(ParseArray());
      End
      Else Begin
        Obj.AddObj(ParseString());
      End;
    End;
    ntoken := NextToken(false);
    If (ntoken <> ']') Then Begin
      Eat(',');
    End;
  End;
  Eat(']');
  result := Obj;
End;

Function TJSONParser.ParseHelper(): TJSONObj;
Var
  Obj: TJSONObj;
  atoken: String;
Begin
  Obj := Nil;
  atoken := NextToken(false);
  If (atoken = '{') Then Begin
    Obj := ParseNode();
  End;
  If (atoken = '[') Then Begin
    Obj := ParseArray();
  End;
  result := Obj;
End;

Function TJSONParser.ParseNode(): TJSONNode;
Var
  Obj: TJSONNode;
  valuename, ntoken: String;
  isstring: Boolean;
  Value: TJSONValue;
Begin
  Obj := TJSONNode.Create;
  Eat('{');
  ntoken := NextToken(false);
  While (ntoken <> '') And (ntoken <> '}') Do Begin
    valuename := NextToken(true);
    Eat(':');
    ntoken := NextToken(false);
    If (ntoken = '[') Then Begin // Der Wert des Nodes ist ein Array von Nodes
      Obj.AddObj(TJSONNodeObj.Create(valuename, ParseArray()));
    End
    Else Begin
      If (ntoken = '{') Then Begin // Der Wert des Nodes ist ein Node
        Obj.AddObj(TJSONNodeObj.Create(valuename, ParseNode()));
      End
      Else Begin
        // Der Wert ist einfach nur wieder ein String / Integer / ..
        ntoken := NextToken(true);
        isstring := fparsedata[fparsedataptr] = '"';
        If ((Not isstring) And (LowerCase(ntoken) = 'null')) Then Begin // Ein Node mit einem Nil Objekt
          ntoken := '';
        End;
        Value := TJSONValue.Create(valuename, ntoken, isstring);
        Obj.AddObj(Value);
      End;
    End;
    ntoken := NextToken(false);
    If (ntoken = ',') Then Begin
      Eat(',');
    End;
  End;
  Eat('}');
  result := Obj;
End;

Function TJSONParser.ParseString(): TJSONTerminal;
Var
  obj: TJSONTerminal;
Begin
  obj := TJSONTerminal.Create(NextToken(true));
  result := obj;
End;

{ TJSONValue }

Constructor TJSONValue.Create(aName, aValue: String; ValueisString: Boolean);
Begin
  Inherited Create;
  fName := aName;
  fvalue := aValue;
  fvalueIsString := ValueisString;
End;

Function TJSONValue.ToString(FrontSpace: String): String;
Begin
  If fvalueIsString Then Begin
    result := FrontSpace + StringToJsonString(fName) + ':' + StringToJsonString(fvalue);
  End
  Else Begin
    result := FrontSpace + StringToJsonString(fName) + ':' + fvalue;
  End;
End;

{ TJSONNodeObj }

Constructor TJSONNodeObj.Create(aName: String; aValue: TJSONObj);
Begin
  Inherited Create;
  fName := aName;
  fvalue := aValue;
End;

Destructor TJSONNodeObj.Destroy;
Begin
  fvalue.Free;
  Inherited;
End;

Function TJSONNodeObj.ToString(FrontSpace: String): String;
Begin
  result := FrontSpace + StringToJsonString(fName) + ':' + fvalue.ToString(FrontSpace);
End;

Function TJSONNodeObj.FindPath(APath: String): TJSONObj;
Begin
  If apath = '' Then Begin
    result := fvalue;
  End
  Else Begin
    Result := Inherited FindPath(APath);
    If (Not assigned(result)) And assigned(fvalue) Then Begin
      result := fvalue.FindPath(APath);
    End;
  End;
End;

End.

