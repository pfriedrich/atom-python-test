{$, ScrollView} = require 'atom-space-pen-views'

module.exports =
  class AtomPythonTestView extends ScrollView

    message: ''
    maximized: false

    @content: ->
      @div class: 'atom-python-test-view native-key-bindings', outlet: 'atomTestView', tabindex: -1, overflow: "auto", =>
        @div class: 'btn-toolbar', outlet:'toolbar', =>
          @button outlet: 'closeBtn', class: 'btn inline-block-tight right', click: 'destroy', style: 'float: right', =>
            @span class: 'icon icon-x'
          @button outlet: 'clearBtn', class: 'btn inline-block-tight right', click: 'clear', style: 'float: right', =>
            @span class: 'icon icon-trashcan'
          @button outlet: 'historyBtn', class: 'btn inline-block-tight right', click: 'showHistory', style: 'float: right', =>
            @span class: 'icon icon-history'
        @pre class: 'output', outlet: 'output'

    initialize: ->
      @panel ?= atom.workspace.addBottomPanel(item: this)
      @message = ""
      @history = []
      @compiled_history = ""
      @panel.hide()
    # TODO: create history field to store previous results

    convertToTwoDigits: (number) ->
      if number < 10
        return '0' + number
      else
        return number

    createTimestamp: ->
      today = new Date
      dd = @convertToTwoDigits(today.getDate())
      # The value returned by getMonth is an integer between 0 and 11,
      # referring 0 to January, 1 to February, and so on.
      mm = @convertToTwoDigits(today.getMonth() + 1)
      yyyy = today.getFullYear()
      hh = @convertToTwoDigits(today.getHours())
      mm2 = @convertToTwoDigits(today.getMinutes())
      ss = @convertToTwoDigits(today.getSeconds())
      today = mm + '-' + dd + '-' + yyyy + " " + hh + ":" + mm2 + ":" + ss
      return today

    addSpanTag: (line, class_to_add = "") ->
      if class_to_add == ""
        new_line = "<span>" + line + "</span>"
      else
        new_line = "<span class='" + class_to_add + "'>" + line + "</span>"
      return new_line

    colorStatus: (line) ->
      parts = line.split(" ")
      new_line = parts[0] + " "
      if parts[1] == "FAILED"
        new_line += @addSpanTag(parts[1], "failure-line")
      else if parts[1] == "PASSED"
        new_line += @addSpanTag(parts[1], "success-line")
      else
        new_line = line
      return new_line

    # TODO: add yellow if "no tests"
    colorLine: (line) ->
      if line.indexOf("failed") > -1 or line.indexOf("E") == 0
        new_line = @addSpanTag(line, "failure-line")
      else if line.indexOf("passed") > -1
        new_line = @addSpanTag(line, "success-line")
      else
        new_line = line
      return new_line

    addToHistory: (lines) ->
      @history.push(lines)

    # TODO: refactor if possible
    # TODO: add coloring to the summary based on results
    compileHistory: ->
      date_pattern = ///^\d\d-\d\d-\d\d\d\d.*///i
      for line, idx in @history
        if idx == 0
          @compiled_history += "<details>"
          @compiled_history += "<summary>"
          @compiled_history += line
          @compiled_history += "</summary>"
        if line.match(date_pattern) and idx > 0
          @compiled_history += "</details>"
          @compiled_history += "<details>"
          @compiled_history += "<summary>"
          @compiled_history += line
          @compiled_history += "</summary>"
        else
         @compiled_history += line
      @compiled_history += "</details>"
      @history = []

    showHistory: ->
      if @history.length > 0
        @compileHistory()
      @clear()
      @find(".output").append(@compiled_history)



    # TODO: add empty line after collected... and before FAILURES/x passed in
    addLine: (lines, do_coloring=false) ->
      for line in lines.split("\n")
        if line == ""
          continue

        @message = line
        if do_coloring
          if line.indexOf("====") > -1 or line.indexOf("E") == 0
            @message = @colorLine(line)
          else if line.indexOf("FAILED") > -1 or line.indexOf("PASSED") > -1
            @message = @colorStatus(line)

        @addToHistory(@message + "\n")
        @find(".output").append(@message + "\n")

    clear: ->
      @message = ''
      virtual_console = @find(".output")[0]
      while virtual_console.firstChild
        virtual_console.removeChild(virtual_console.firstChild)

    finish: ->
      console.log('finish')

    destroy: ->
      @panel.hide()

    reset: -> @message = defaultMessage

    toggle: ->
      @find(".output").height(300)
      @addLine @createTimestamp()
      @addLine "Running tests... "
      @panel.show()
