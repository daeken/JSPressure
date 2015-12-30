import coffeescript, json, shutil, yaml
from flask import Flask, Response
app = Flask(__name__)
app.debug = True

@app.route('/')
def index():
	shutil.copyfile('index.html', 'build/index.html')
	return file('index.html').read()

@app.route('/<name>.js')
def js(name):
	try:
		code = file('scripts/' + name + '.js').read()
	except:
		code = coffeescript.compile(file('scripts/' + name + '.coffee').read(), bare=True)
	with file('build/%s.js' % name, 'w') as fp:
		fp.write(code)
	return code

@app.route('/materials.json')
def materials():
	js = json.dumps(yaml.load(file('materials.yaml')))
	with file('build/materials.json', 'w') as fp:
		fp.write(js)
	return Response(js, 'application/json')

if __name__=='__main__':
	app.run()
