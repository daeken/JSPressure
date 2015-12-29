import coffeescript, json, yaml
from flask import Flask, Response
app = Flask(__name__)
app.debug = True

@app.route('/')
def index():
	return file('index.html').read()

@app.route('/<name>.js')
def js(name):
	try:
		return file('scripts/' + name + '.js').read()
	except:
		return coffeescript.compile(file('scripts/' + name + '.coffee').read(), bare=True)

@app.route('/materials.json')
def materials():
	return Response(json.dumps(yaml.load(file('materials.yaml'))), 'application/json')

if __name__=='__main__':
	app.run()
