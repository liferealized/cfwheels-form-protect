<cfcomponent mixin="controller" output="false">

  <cffunction name="init" access="public" output="false" returntype="any">
    <cfscript>
      var loc = {};

      _addSettings();

      this.version = "1.1.7,1.1.8,1.4.5,2.0";

      loc.settings = application.formprotect;

      // add in the formprotect.js file for when we are in design / develop / maintenance environments
      if (!FileExists(ExpandPath("javascripts/#loc.settings.jsfilename#")))
        FileCopy(ExpandPath("plugins/formprotect/javascripts/#loc.settings.jsfilename#"), ExpandPath("javascripts/#loc.settings.jsfilename#"));
    </cfscript>
    <cfreturn this />
  </cffunction>

  <cffunction name="protectForms" access="public" output="false" returntype="void">
    <cfscript>
      filters(type="before", through="verifyFormProtection");
    </cfscript>
  </cffunction>

  <!--- controller helpers --->

  <cffunction name="verifyFormProtection" access="public" output="false" returntype="void">
    <cfargument name="settings" type="struct" required="false" default="#application.formprotect#" />
    <cfscript>
      var loc = { points = 0 };

      if (isGet() || isHead() || isOptions())
        return;

      for (loc.setting in arguments.settings)
        if (isStruct(arguments.settings) and structKeyExists(variables, "verify" & loc.setting))
          loc.points += $invoke(method="verify" & loc.setting);

      if (loc.points gte arguments.settings.maxpoints)
        $throw(
          type="Wheels.formprotect.FormFailed",
          message = "The form failed our sanity checks with #loc.points# points which exceeds the threshold of #arguments.settings.maxpoints#."
        );
    </cfscript>
    <cfreturn />
  </cffunction>

  <cffunction name="verifyMouseMovement" access="public" output="false" returntype="numeric">
    <cfargument name="params" type="struct" required="false" default="#variables.params#" />
    <cfargument name="settings" type="struct" required="false" default="#application.formprotect#" />
    <cfreturn (structKeyExists(arguments.params, "formfield1234567891") and isNumeric(arguments.params.formfield1234567891)) ? 0 : arguments.settings.mousemovement.points />
  </cffunction>

  <cffunction name="verifyKeyboardUsed" access="public" output="false" returntype="numeric">
    <cfargument name="params" type="struct" required="false" default="#variables.params#" />
    <cfargument name="settings" type="struct" required="false" default="#application.formprotect#" />
    <cfreturn (structKeyExists(arguments.params, "formfield1234567892") and isNumeric(arguments.params.formfield1234567892)) ? 0 : arguments.settings.keyboardused.points />
  </cffunction>

  <cffunction name="verifyTimedTest" access="public" output="false" returntype="numeric">
    <cfargument name="params" type="struct" required="false" default="#variables.params#" />
    <cfargument name="settings" type="struct" required="false" default="#application.formprotect#" />
    <cfscript>
      var loc = {};

      if (!structKeyExists(arguments.params, "formfield1234567893") or listLen(arguments.params.formfield1234567893) neq 2)
        return arguments.settings.timedtest.points;

      loc.date = listFirst(arguments.params.formfield1234567893) - arguments.settings.timesecret;
      loc.time = listLast(arguments.params.formfield1234567893) - arguments.settings.timesecret;

      if (len(loc.date) neq 8 or len(loc.time) neq 6)
        return arguments.settings.timedtest.points;

      loc.datetime = createDateTime(left(loc.date, 4), mid(loc.date, 5, 2), right(loc.date, 2), left(loc.time, 2), mid(loc.time, 3, 2), right(loc.time, 2));
      loc.diffSecs = dateDiff("s", loc.datetime, now());

      if (loc.diffSecs lt arguments.settings.timedtest.min or loc.diffSecs gt arguments.settings.timedtest.max)
        return arguments.settings.timedtest.points;
    </cfscript>
    <cfreturn 0 />
  </cffunction>

  <cffunction name="verifyNegativeTest" access="public" output="false" returntype="numeric">
    <cfargument name="params" type="struct" required="false" default="#variables.params#" />
    <cfargument name="settings" type="struct" required="false" default="#application.formprotect#" />
    <cfreturn (structKeyExists(arguments.params, "formfield1234567894") and !len(arguments.params.formfield1234567894)) ? 0 : arguments.settings.negativetest.points />
  </cffunction>

  <cffunction name="verifySpamStrings" access="public" output="false" returntype="numeric">
    <cfargument name="params" type="struct" required="false" default="#variables.params#" />
    <cfargument name="settings" type="struct" required="false" default="#application.formprotect#" />
    <cfreturn (reFindNoCase(arguments.settings.spamstrings.regex, serializeJSON(arguments.params))) ? arguments.settings.spamstrings.points : 0 />
  </cffunction>

  <cffunction name="verifyUrlCount" access="public" output="false" returntype="numeric">
    <cfargument name="params" type="struct" required="false" default="#variables.params#" />
    <cfargument name="settings" type="struct" required="false" default="#application.formprotect#" />
    <cfreturn (arrayLen(reMatch("http://|https://", serializeJSON(arguments.params))) gt arguments.settings.urlcount.max) ? arguments.settings.urlcount.points : 0 />
  </cffunction>

  <!--- view helpers --->

  <cffunction name="startFormTag" access="public" output="false" returntype="string">
    <cfset var loc = {} />
    <!--- use savecontent so the html written isn't just one long string --->
    <cfsavecontent variable="loc.formStart">
      <cfoutput>
        #core.startFormTag(argumentCollection=arguments)#

        #mouseMovementHiddenTag()#
        #keyboardUsedHiddenTag()#
        #timedTestHiddenTag()#
        #negativeTestHiddenField()#
      </cfoutput>
    </cfsavecontent>
    <cfreturn loc.formStart />
  </cffunction>

  <cffunction name="mouseMovementHiddenTag" access="public" output="false" returntype="string">
    <cfreturn hiddenFieldTag(name="formfield1234567891", id=createUUID(), value="", class="cfw-fp-mm") />
  </cffunction>

  <cffunction name="keyboardUsedHiddenTag" access="public" output="false" returntype="string">
    <cfreturn hiddenFieldTag(name="formfield1234567892", id=createUUID(), value="", class="cfw-fp-kp") />
  </cffunction>

  <cffunction name="timedTestHiddenTag" access="public" output="false" returntype="string">
    <cfscript>
      var loc = {
          date = dateFormat(now(), "yyyymmdd") + application.formprotect.timesecret
        , time = timeFormat(now(), "HHmmss") + application.formprotect.timesecret
      };
    </cfscript>
    <cfreturn hiddenFieldTag(name="formfield1234567893", id=createUUID(), value=loc.date & "," & loc.time) />
  </cffunction>

  <cffunction name="negativeTestHiddenField" access="public" output="false" returntype="string">
    <cfscript>
      var loc = { id = createUUID() };
      loc.field = textFieldTag(name="formfield1234567894", id=loc.id, value="", label="Leave this field empty");
    </cfscript>
    <cfreturn $element(name="span", content=loc.field, attributes={ style=application.formprotect.hidestyle }) />
  </cffunction>

  <!--- private methods --->

  <cffunction name="_addSettings" access="private" output="false" returntype="void">
    <cfscript>
      var loc = {};

      loc.settings = {
          mousemovement = { points =  1 }
        , negativetest  = { points = 10 }
        , keyboardused  = { points =  1 }
        , timedtest     = { points =  1, max = 600, min = 5 }
        , urlcount      = { points =  1, max =   3 }
        , spamstrings   = { points =  1, regex = "free music|download music|music downloads|viagra|phentermine|viagra|tramadol|ultram|prescription soma|cheap soma|cialis|levitra|weight loss|buy cheap" }
        , hidestyle     = "position:absolute;visibility:hidden;top:-20000px"
        , hashsecret    = "tH1sI5myL!tTl3HasH5ekr3T$"
        , jsfilename    = "formprotect.js"
        , timesecret    = 23440205
        , maxpoints     = 3
      };

      if (!structKeyExists(application, "formprotect"))
        application.formprotect = loc.settings;
    </cfscript>
  </cffunction>

</cfcomponent>
