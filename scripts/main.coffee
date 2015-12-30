Number.prototype.trunc = (digits) ->
	exp = Math.pow 10, digits
	Math.floor(this * exp) / exp

class JSPressure
	constructor: ->
		$.getJSON 'materials.json', (@materials) =>
			$('#main-category').append('<option disabled selected></option>')
			for k, v of @materials
				$('#main-category').append('<option value="' + k + '">' + k + '</option>')
			@load()
		$('#main-category').change =>
			$('#sub-category').children().remove()
			$('#material-name').children().remove()
			$('#sub-category').append('<option disabled selected></option>')
			$('#material-name').append('<option disabled selected></option>')
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

		@shape = 'tube'
		$('#shape').change =>
			@shape = $('#shape').val()
			$('#geometry-tube').hide()
			$('#geometry-sphere').hide()
			$('#geometry-' + @shape).show()

		$('input:enabled, select').change @update

	save: =>
		$('input:enabled,select').each (i, e) ->
			if $(e).val()
				localStorage.setItem e.id, $(e).val()

	load: =>
		$('input:enabled,select').each (i, e) ->
			nv = localStorage.getItem(e.id)
			$(e).val(nv)
			$(e).change()

	update: =>
		@save()

		@calculate_volume()

	f: (name) ->
		parseFloat($('#' + name).val())

	calculate_volume: ->
		if @shape == 'tube'
			ir = @f('tube-id') / 2
			wall = @f('tube-thickness')
			trad = ir + wall
			length = @f('tube-length')

			total_volume = Math.PI * (trad * trad) * length
			inner_volume = Math.PI * (ir * ir) * length

			@volume = total_volume - inner_volume
		else if @shape == 'sphere'
			ir = @f('sphere-id') / 2
			wall = @f('sphere-thickness')
			tr = ir + wall
			
			total_volume = 4 / 3 * Math.PI * tr * tr * tr
			inner_volume = 4 / 3 * Math.PI * ir * ir * ir

			@volume = total_volume - inner_volume

		$('#volume').text @volume
		@weight_lbs = @volume / 16387 * @f('density') # Volume is mm^3, density is lbs/in^3
		@weight_kg = @weight_lbs / 2.2046
		$('#mass-lbs').text @weight_lbs.trunc(4)
		$('#mass-kg').text @weight_kg.trunc(4)

		water_lbs = @weight_lbs - (total_volume / 16387 * 0.03704) # Density of water, 1025.3 kg/m^3
		water_kg = water_lbs / 2.2046
		$('#water-lbs').text water_lbs.trunc(4)
		$('#water-kg').text water_kg.trunc(4)

# q = unit pressure, a = outer radius, b = inner radius, l = length, E = modulus of elasticity, v = Poisson's ratio
# page 683
thick_cylinder_1c = (q, a, b, l, E, v) ->
	r = (a - b) / 2 + b

	s1 = (-q * a * a) / (a*a - b*b) # THIS IS WRONG -- copied from 1d
	s2 = (-q * a * a * (b * b + r * r)) / (r*r * (a*a - b*b))
	s2_max = (-q * 2 * a * a) / (a * a - b * b)
	s3 = (-q * a * a * (r * r - b * b)) / (r * r * (a * a - b * b))
	s3_max = -q

	t_max = s2_max / 2
	da = ((-q * a) / E) * (((a * a + b * b) / (a * a - b * b)) - v)
	db = (-q / E) * ((2 * a * a) / (a * a - b * b))
	dl = ((q * v * l) / E) * ((2 * a * a) / (a * a - b * b))
	console.log da * 2.54, db * 2.54, dl * 2.54

sq = (x) -> x * x

mises = (a, b, c) ->
	Math.sqrt(.5 * (sq(a - b) + sq(b - c) + sq(c - a)))

# q = unit pressure [psi], a = outer radius [in], b = inner radius [in], l = length [in], 
# E = modulus of elasticity [psi], v = Poisson's ratio
# page 684
thick_cylinder_1d = (q, a, b, l, E, v) ->
	r = (a - b) / 2 + b

	s1 = (-q * a * a) / (a*a - b*b)
	s2_max = (-q * 2 * a * a) / (a * a - b * b)

	equiv = mises(s1, s2_max, 0)

	da = ((-q * a) / E) * ((a * a * (1 - 2 * v) + b * b * (1 + v)) / (a * a - b * b))
	db = ((-q * b) / E) * ((a * a * (2 - v)) / (a * a - b * b))
	dl = ((-q * l) / E) * ((a * a * (1 - 2 * v)) / (a * a - b * b))

	# Max axial stress [psi], Max hoop stress [psi], Max equiv stress [psi]
	# ID deviation [mm], OD deviation [mm], length deviation [mm]
	[s1, s2_max, equiv,
	 db * 25.4 * 2, da * 25.4 * 2, dl * 25.4]

$ ->
	new JSPressure
