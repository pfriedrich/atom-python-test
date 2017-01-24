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
      @compiled_history = ""
      @history = []
      @panel.hide()

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

    addToHistory: (lines) ->
      # if @history.length < 100000
      @history.push(lines)
      # else
      #   @history.pop()
      #   @history.unshift(lines)

    # TODO: refactor if possible
    # TODO: add coloring to the summary based on results
    compileHistory: ->
      date_pattern = ///^\d\d-\d\d-\d\d\d\d.*///i
      for line, idx in @history
        if idx == 0
          @compiled_history += "<details>"
          @compiled_history += "<summary>#{line}</summary>"
        else if line.match(date_pattern)
          @compiled_history += "</details>"
          @compiled_history += "<details>"
          @compiled_history += "<summary>#{line}</summary>"
        else
         @compiled_history += "<div class='history-line'>#{line}</div>"
      @compiled_history += "</details>"
      @history = []

    showHistory: ->
      @clear()
      if @history.length > 0
        @compileHistory()
      @find(".output").append(@compiled_history)

    addSpanTag: (text, class_to_add = "") ->
      new_text = "<span class=#{class_to_add}>#{text}</span>"
      return new_text

    colorStatus: (parts, class_to_add) ->
      colored_status = @addSpanTag(parts[1], class_to_add)
      new_line = parts[0] + " " + colored_status

      return new_line

    # TODO: add yellow if "no tests"
    colorLine: (line) ->
      new_line = line

      if line.indexOf("====") > -1
        if line.indexOf("failed") > -1
          new_line = @addSpanTag(line, class_to_add="failure-line")

        else if line.indexOf("passed") > -1
          new_line = @addSpanTag(line, class_to_add="success-line")

      else if line.indexOf("E") == 0
        new_line = @addSpanTag(line, class_to_add="failure-line")

      else
        parts = line.split(" ")
        if parts[1] == "FAILED"
          new_line = @colorStatus(parts, class_to_add="failure-line")

        else if parts[1] == "PASSED"
          new_line = @colorStatus(parts, class_to_add="success-line")

      return new_line

    # TODO: add empty line after collected... and before FAILURES/x passed in
    addLine: (lines, do_coloring=false) ->
      for line in lines.split("\n")
        if line == ""
          continue

        if do_coloring
          @message = @colorLine(line)
        else
          @message = line

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
