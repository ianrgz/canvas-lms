define [
  'i18n!assignments'
  'underscore'
  'compiled/models/AssignmentGroup'
  'compiled/collections/NeverDropCollection'
  'compiled/views/assignments/NeverDropCollectionView'
  'compiled/views/DialogFormView'
  'jst/assignments/CreateGroup'
  'jst/EmptyDialogFormWrapper'
], (I18n, _, AssignmentGroup, NeverDropCollection, NeverDropCollectionView, DialogFormView, template, wrapper) ->

  class CreateGroupView extends DialogFormView
    defaults:
      width: 600
      height: 500

    events: _.extend({}, @::events,
      'click .dialog_closer': 'close'
    )

    els:
      '.never_drop_rules_group': '$neverDropContainer'

    template: template
    wrapperTemplate: wrapper

    @optionProperty 'assignmentGroups'
    @optionProperty 'assignmentGroup'
    @optionProperty 'course'

    messages:
      non_number: I18n.t('non_number', 'You must use a number')
      positive_number: I18n.t('positive_number', 'You must use a positive number')
      max_number: I18n.t('higher_than_max', 'You cannot use a number greater than the number of assignments')

    initialize: ->
      super
      #@assignmentGroup will be defined when editing
      @model = @assignmentGroup or new AssignmentGroup(assignments: [])


    onSaveSuccess: ->
      super
      if @assignmentGroup # meaning we are editing
        @model.collection.view.render()
      else
        @assignmentGroups.add(@model)
        @model = new AssignmentGroup(assignments: [])

      @render()

    getFormData: ->
      data = super
      delete data.rules.drop_lowest if _.contains(["", "0"], data.rules.drop_lowest)
      delete data.rules.drop_highest if _.contains(["", "0"], data.rules.drop_highest)
      delete data.rules.never_drop if data.rules.never_drop?.length == 0
      data

    validateFormData: (data) ->
      max = null
      if @assignmentGroup
        as = @assignmentGroup.get('assignments')
        max = as.size() if as?
      errors = {}
      _.each data.rules, (value, name) =>
        val = parseInt(value)
        field = "rules[#{name}]"
        if isNaN(val)
          errors[field] = [{type: 'number', message: @messages.non_number}]
        if val < 0
          errors[field] = [{type: 'positive_number', message: @messages.positive_number}]
        if max?
          if val > max
            errors[field] = [{type: 'maximum', message: @messages.max_number}]
      errors

    showWeight: ->
      course = @course or @model.collection?.course
      course?.get('apply_assignment_group_weights')

    checkGroupWeight: ->
      if @showWeight()
        @$el.find('.group_weight').removeAttr("disabled")
      else
        @$el.find('.group_weight').attr("disabled", "disabled")

    getNeverDrops: ->
      @$neverDropContainer.empty()
      rules = @model.rules()
      @never_drops = new NeverDropCollection [],
        assignments: @model.get('assignments')
        ag_id: @model.get('id') or 'new'

      @ndCollectionView = new NeverDropCollectionView
        collection: @never_drops

      @$neverDropContainer.append @ndCollectionView.render().el
      if rules && rules.never_drop
        @never_drops.reset rules.never_drop,
          parse: true


    toJSON: ->
      data = @model.toJSON()
      _.extend(data, {
        disable_weight: !@showWeight()
        group_weight: if @showWeight() then data.group_weight else null
        label_id: @model.get('id') or 'new'
        drop_lowest: @model.rules()?.drop_lowest or 0
        drop_highest: @model.rules()?.drop_highest or 0
        editable_never_drop: @model.get('assignments').length > 0
      })

    openAgain: ->
      super
      @checkGroupWeight()
      @getNeverDrops()
