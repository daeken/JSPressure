Number.prototype.trunc = (digits) ->
	exp = Math.pow 10, digits
	Math.floor(this * exp) / exp

class JSPressure
	constructor: ->
		@loaded = false
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
		@loaded = true

	update: =>
		if @loaded
			@save()

		@calculate_volume()
		[psi, stresses] = @search_fail()
		$('#fail-psi').text psi.trunc(3)
		$('#fail-depth').text psi2seadepth(psi).trunc(3)

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

	# Returns true/false for pass/fail, then stresses relevant to geometry
	calculate_stress: (psi) ->
		if @shape == 'tube'
			[axial, hoop, equiv, did, dod, dl] = thick_cylinder_1d(
				psi, 
				@f('tube-id') + @f('tube-thickness') * 2, 
				@f('tube-id'), 
				@f('tube-length'), 
				@f('young') * 1000000, # Mpsi -> Psi
				@f('poisson')
			)
		else if @shape == 'sphere'
			[merid, hoop, equiv, did, dod] = thick_sphere_2b(
				psi, 
				@f('sphere-id') + @f('sphere-thickness') * 2, 
				@f('sphere-id'), 
				@f('young') * 1000000, # Mpsi -> Psi
				@f('poisson')
			)

		if @cattype == 'Metals'
			pass = @f('yield-strength') > equiv / 1000
		else if @cattype == 'Plastics'
			pass = @f('ult') > Math.abs(hoop) / 1000
		else if @cattype == 'Ceramics' or @cattype == 'Glass'
			pass = @f('ult-comp') > Math.abs(hoop) / 1000

		if @shape == 'tube'
			[pass, [axial, hoop, equiv, did, dod, dl]]
		else if @shape == 'sphere'
			[pass, [merid, hoop, equiv, did, dod]]

	# Returns pressure and stresses relevant to geometry for failing case
	search_fail: ->
		recur = (low, high) =>
			if high - low <= 1
				return [high, @calculate_stress(high)[1]]
			else
				mid = (high - low) / 2 + low
				if @calculate_stress(mid)[0] == true # midpoint pass
					return recur(mid, high)
				else
					return recur(low, mid)
		[psi, stresses] = recur(1, 10000000)
		console.log psi, stresses
		[psi, stresses]

mm2in = (x) -> x / 25.4
# Depth in m
psi2seadepth = (psi) -> ((-0.444 + Math.sqrt(.444 * .444 - 4 * (.3 / (1000 * 1000)) * -psi)) / (2 * (.3 / (1000 * 1000)))) * .3048

sq = (x) -> x * x

mises = (a, b, c) ->
	Math.sqrt(.5 * (sq(a - b) + sq(b - c) + sq(c - a)))

# q = unit pressure [psi], a = outer diameter [mm], b = inner diameter [mm], l = length [mm], 
# E = modulus of elasticity [psi], v = Poisson's ratio
# page 684
thick_cylinder_1d = (q, a, b, l, E, v) ->
	a = mm2in(a) / 2
	b = mm2in(b) / 2
	l = mm2in(l)

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

# q = unit pressure [psi], a = outer diameter [mm], b = inner diameter [mm], 
# E = modulus of elasticity [psi], v = Poisson's ratio
# page 685
thick_sphere_2b = (q, a, b, E, v) ->
	a = mm2in(a) / 2
	b = mm2in(b) / 2

	ac = a * a * a
	bc = b * b * b

	s1 = s2 = (-q * 3 * ac) / (2 * (ac - bc))
	equiv = mises(s1, s2, 0)

	da = ((-q * a) / E) * (((1 - v) * (bc + 2 * ac)) / (2 * (ac - bc)) - v)
	db = ((-q * b) / E) * ((3 * (1 - v) * ac) / (2 * (ac - bc)))

	[s1, s2, equiv, 
	 db * 25.4 * 2, da * 25.4 * 2]

$ ->
	new JSPressure
