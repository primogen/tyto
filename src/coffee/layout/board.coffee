Column = require './column'

module.exports = Backbone.Marionette.CompositeView.extend
  tagName           : 'div'
  className         : 'board'
  template          : Tyto.templateStore.board
  templateHelpers   : ->
    undoables: Tyto.UndoHandler.undoables
  childView         : Column
  childViewContainer: '.columns'
  childViewOptions: (c) ->
    colTasks = Tyto.taskList.where
      columnId: c.id
    boardView = this
    collection : new Tyto.Tasks.TaskList colTasks
    boardView  : boardView
    board      : boardView.model
    siblings   : boardView.collection
  ui:
    addColumn  : '#add-column'
    deleteBoard: '#delete-board'
    wipeBoard  : '#wipe-board'
    boardName  : '#board-name'
    superAdd   : '#super-add'
    undoBtn    : '#undo'

  events:
    'click @ui.addColumn'  : 'addColumn'
    'click @ui.deleteBoard': 'deleteBoard'
    'click @ui.wipeBoard'  : 'wipeBoard'
    'blur @ui.boardName'   : 'updateName'
    'click @ui.superAdd'   : 'superAddTask'
    'click @ui.undoBtn'    : 'undoLastAction'

  undoLastAction: ->
    Tyto.UndoHandler.undo()

  initialize: ->
    board            = this


    board.collection.on 'remove', (mod, col, opts) ->
      newWidth = (100 / board.collection.length) + '%'
      $('.column').css
        width: newWidth
      if !opts.ignore
        Tyto.UndoHandler.register
          action    : 'REMOVE-COLUMN'
          model     : mod
          collection: col

    board.collection.on 'add', (mod, col, opts) ->
      newWidth = (100 / board.collection.length) + '%'
      $('.column').css
        width: newWidth
      if !opts.ignore
        Tyto.UndoHandler.register
          action    : 'ADD-COLUMN'
          model     : mod
          collection: col

    # This is needed to ensure that our undo button displays correctly
    # Tyto.undoables.on 'all', this.render

  onBeforeRender: ->
    # This ensures that even after moving a column that when we add
    # something new that the ordinal property of each column is respected.
    this.collection.models = this.collection.sortBy 'ordinal'

  onRender: ->
    this.bindColumns()


  bindColumns: ->
    self        = this
    model       = `undefined`
    list        = `undefined`
    oldPos      = `undefined`
    this.$el.find('.columns').sortable
      connectWith: '.column',
      handle     : '.column--mover'
      placeholder: 'column-placeholder'
      axis       : "x"
      containment: this.$el.find('.columns')
      opacity    : 0.8
      start      : (event, ui) ->
        model       = self.collection.get ui.item.attr('data-col-id')
        oldPos      = model.get 'ordinal'
      stop       : (event, ui) ->
        list        = Array.prototype.slice.call self.$el.find '.column'

        Tyto.reorder self, list, 'data-col-id'

        Tyto.UndoHandler.register
          action  : 'MOVE-COLUMN'
          oldPos  : oldPos
          model   : model
          list    : list
          view    : self
          attr    : 'data-col-id'


  addColumn: ->
    board = this.model
    newCol = new Tyto.Columns.Column
      id     : _.uniqueId()
      boardId: board.id
      ordinal: this.collection.length + 1

    # NOTE localStorage use must have been accepted.
    newCol.save()

    this.collection.add newCol

  updateName: ->
    this.model.set 'title', @ui.boardName.text().trim()
    this.model.save()

  superAddTask: ->
    board = this.model
    newTask = new Tyto.Tasks.Task
      id     : _.uniqueId()
      ordinal: this.collection.length + 1
      boardId: board.id

    # NOTE localStorage usage must've been accepted by this point
    newTask.save()

    Tyto.taskList.add newTask

    Tyto.navigate '#board/' + board.id + '/task/' + newTask.id, true

  deleteBoard: ->
    view = this
    view.wipeBoard()
    view.model.destroy()
    view.destroy()
    Tyto.navigate '/',
      trigger: true

  wipeBoard: ->
    view = this
    if confirm 'are you sure???'
      view.children.forEach (colView) ->
        colView.collection.forEach (taskModel) ->
          taskModel.destroy()
        colView.model.destroy()
    return
