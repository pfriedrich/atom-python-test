AtomPythonTestView = require './atom-python-test-view'
{CompositeDisposable} = require 'atom'

fs = require 'fs-plus'

module.exports = AtomPythonTest =

  atomPythonTestView: null

  modalPanel: null

  subscriptions: null

  # TODO: put order in the options (and potentially rename/rephrase some)
  config:
    executeDocTests:
      type: 'boolean'
      default: false
      title: 'Execute doc tests on test runs'
    additionalArgs:
      type: 'string'
      default: ''
      title: 'Additional arguments for pytest command line'
    outputColored:
      type: 'boolean'
      default: false
      title: 'Color the output'
    coverage:
      type: 'object'
      properties:
        run:
          type: 'boolean'
          default: false
          title: 'Always ask for coverage report on test runs'
        suffixPrefix:
          type: 'string'
          default: 'test_'
          title: 'Prefix/Suffix of your UT script'



  activate: (state) ->

    @atomPythonTestView = new AtomPythonTestView(state.atomPythonTestViewState)

    # Events subscribed to in atom's system can be easily cleaned up with a CompositeDisposable
    @subscriptions = new CompositeDisposable

    # Register command that toggles this view
    # TODO: add a new option to run with coverage
    @subscriptions.add atom.commands.add 'atom-workspace', 'atom-python-test:run-all-tests': => @runAllTests()
    @subscriptions.add atom.commands.add 'atom-workspace', 'atom-python-test:run-all-tests-verbose': => @runAllTests(verbose=true)
    @subscriptions.add atom.commands.add 'atom-workspace', 'atom-python-test:run-test-under-cursor': => @runTestUnderCursor()

  deactivate: ->
    @subscriptions.dispose()
    @atomPythonTestView.destroy()

  serialize: ->
    atomPythonTestViewState: @atomPythonTestView.serialize()

  executePyTest: (filePath, verbose=false) ->
    {BufferedProcess} = require 'atom'

    @tmp = require('tmp');

    @atomPythonTestView.clear()
    @atomPythonTestView.toggle()

    stdout = (output) ->
      atomPythonTestView = AtomPythonTest.atomPythonTestView
      do_coloring = atom.config.get('atom-python-test.outputColored')
      atomPythonTestView.addLine output, do_coloring

    exit = (code) ->
      atomPythonTestView = AtomPythonTest.atomPythonTestView

      junitViewer = require('junit-viewer')
      parsedResults = junitViewer.parse(AtomPythonTest.testResultsFilename.name)

      if parsedResults.junit_info.tests.error > 0 and code != 0
        atomPythonTestView.addLine "An error occured while executing py.test.
          Check if py.test is installed and is in your path."

    @testResultsFilename = @tmp.fileSync({prefix: 'results', keep : true, postfix: '.xml'});

    executeDocTests = atom.config.get('atom-python-test.executeDocTests')

    command = 'python'
    args = ['-m', 'pytest', filePath, '--junit-xml=' + @testResultsFilename.name]

    # TODO: handle coverage config file
    # FIXME: this creates a .coverage file in the package folder
    runCoverage = atom.config.get('atom-python-test.coverage.run')
    if runCoverage

        # TODO: see if we can handle the case where suffix/prefix is wrong
        # TODO: make it so that suffixPrefix can be a list
        suffixPrefix = atom.config.get('atom-python-test.coverage.suffixPrefix')

        testPathParts = filePath.split "/"
        testName = testPathParts[testPathParts.length - 1]
        mutName = testName.replace suffixPrefix, ""

        # TODO: see if we can avoid looping if test in same dir than mut 

        console.log(mutName)

        # TODO: make this better
        projectPath = atom.project.getPaths()[0]
        # console.log(projectPath)

        files = fs.listTreeSync(projectPath)
        # console.log(files)

        for f in files
            # TODO: make better regex
            if f.indexOf(mutName) > -1 and f.indexOf("pyc") == -1
                mutPath = f
                console.log(mutPath)
                break

        args.push ('--cov=' + mutPath)


    if executeDocTests
      args.push '--doctest-modules'

    if verbose
      args.push '--verbose'

    additionalArgs = atom.config.get('atom-python-test.additionalArgs')
    if additionalArgs
      args = args.concat additionalArgs.split " "

    process = new BufferedProcess({command, args, stdout, exit})


  runTestUnderCursor: ->
    editor = atom.workspace.getActiveTextEditor()
    file = editor?.buffer.file
    filePath = file?.path
    selectedText = editor.getSelectedText()

    testLineNumber = editor.getCursorBufferPosition().row
    testIndentation = editor.indentationForBufferRow(testLineNumber)

    class_re = /class \w*\((\w*.*\w*)*\):/
    buffer = editor.buffer

    # Starts searching backwards from the test line until we find a class. This
    # guarantee that the class is a Test class, not an utility one.
    reversedLines = buffer.lines[0...testLineNumber].reverse()

    for line, i in reversedLines
      startIndex = line.search(class_re)

      classLineNumber = testLineNumber - i - 1

      # We think that we have found a Test class, but this is guaranteed only if
      # the test indentation is greater than the class indentation.
      classIndentation = editor.indentationForBufferRow(classLineNumber)
      if startIndex != -1 and testIndentation > classIndentation
        endIndex = line.indexOf('(')
        startIndex = startIndex + 6
        className = line[startIndex...endIndex]
        filePath = filePath + '::' + className
        break

    re = /test(\w*|\W*)/;
    content = editor.buffer.lines[testLineNumber]
    endIndex = content.indexOf('(')
    startIndex = content.search(re)
    testName = content[startIndex...endIndex]

    if testName
      filePath = filePath + '::' + testName
      @executePyTest(filePath)

  runAllTests: (verbose=false) ->
    editor = atom.workspace.getActivePaneItem()
    file = editor?.buffer.file
    filePath = file?.path
    @executePyTest(filePath, verbose)
