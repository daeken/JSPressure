class JSPressure
	constructor: ->
		$.getJSON '/materials.json', (@materials) =>
			$('#main-category').append('<option disabled selected></option>')
			for k, v of @materials
				$('#main-category').append('<option value="' + k + '">' + k + '</option>')
		$('#main-category').change =>
			$('#sub-category').children().remove()
			$('#sub-category').append('<option disabled selected></option>')
			cat = $('#main-category').val()
			@cattype = cat
			@cat = @materials[cat]
			if not @cat
				return
			for k, v of @cat
				$('#sub-category').append('<option value="' + k + '">' + k + '</option>')
		$('#sub-category').change =>
			$('#material-name').children().remove()
			$('#material-name').append('<option disabled selected></option>')
			subcat = $('#sub-category').val()
			@subcat = @cat[subcat]
			if not @subcat
				return
			for k, v of @subcat
				$('#material-name').append('<option value="' + k + '">' + k + '</option>')
		$('#material-name').change =>
			@mat = $('#material-name').val()
			material = @subcat[@mat]
			$('#cg-qual').hide()
			$('#metal-qual').hide()
			$('#plastic-qual').hide()
			if @cattype == 'Ceramics' or @cattype == 'Glass'
				$('#cg-qual').show()
				[ust, usc, ym, den, pr] = material
				$('#ult-tensile').val ust
				$('#ult-comp').val usc
			else if @cattype == 'Metals'
				$('#metal-qual').show()
				[ys, ym, den, pr] = material
				$('#yield-strength').val ys
			else if @cattype == 'Plastics'
				$('#plastic-qual').show()
				[us, ws, ym, den, pr] = material
				$('#ult').val us
				$('#working').val ws
			$('#young').val ym
			$('#density').val den
			$('#poisson').val pr


$ ->
	new JSPressure
