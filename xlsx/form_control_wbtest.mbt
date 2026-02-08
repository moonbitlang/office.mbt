///|
test "form control vml parse checked false values" {
  let xml =
    #|<xml xmlns:v="urn:schemas-microsoft-com:vml" xmlns:x="urn:schemas-microsoft-com:office:excel">
    #|  <v:shape id="_x0000_s1025">
    #|    <x:ClientData ObjectType="CheckBox">
    #|      <x:Anchor>0,0,0,0,1,0,1,0</x:Anchor>
    #|      <x:Checked>False</x:Checked>
    #|    </x:ClientData>
    #|  </v:shape>
    #|  <v:shape id="_x0000_s1026">
    #|    <x:ClientData ObjectType="CheckBox">
    #|      <x:Anchor>0,0,1,0,1,0,2,0</x:Anchor>
    #|      <x:Checked>false</x:Checked>
    #|    </x:ClientData>
    #|  </v:shape>
    #|  <v:shape id="_x0000_s1027">
    #|    <x:ClientData ObjectType="CheckBox">
    #|      <x:Anchor>0,0,2,0,1,0,3,0</x:Anchor>
    #|      <x:Checked>0</x:Checked>
    #|    </x:ClientData>
    #|  </v:shape>
    #|</xml>
  let controls = parse_form_controls_vml(xml)
  inspect(controls.length(), content="3")
  inspect(controls[0].cell, content="A1")
  inspect(controls[0].checked, content="Some(false)")
  inspect(controls[1].cell, content="A2")
  inspect(controls[1].checked, content="Some(false)")
  inspect(controls[2].cell, content="A3")
  inspect(controls[2].checked, content="Some(false)")
}

///|
test "form control vml parse checked true values" {
  let xml =
    #|<xml xmlns:v="urn:schemas-microsoft-com:vml" xmlns:x="urn:schemas-microsoft-com:office:excel">
    #|  <v:shape id="_x0000_s1030">
    #|    <x:ClientData ObjectType="CheckBox">
    #|      <x:Anchor>0,0,0,0,1,0,1,0</x:Anchor>
    #|      <x:Checked>1</x:Checked>
    #|    </x:ClientData>
    #|  </v:shape>
    #|  <v:shape id="_x0000_s1031">
    #|    <x:ClientData ObjectType="CheckBox">
    #|      <x:Anchor>0,0,1,0,1,0,2,0</x:Anchor>
    #|      <x:Checked>true</x:Checked>
    #|    </x:ClientData>
    #|  </v:shape>
    #|</xml>
  let controls = parse_form_controls_vml(xml)
  inspect(controls.length(), content="2")
  inspect(controls[0].cell, content="A1")
  inspect(controls[0].checked, content="Some(true)")
  inspect(controls[1].cell, content="A2")
  inspect(controls[1].checked, content="Some(true)")
}
