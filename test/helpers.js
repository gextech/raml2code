var path = require('path');
var fs = require('fs');
var raml2code = require('..');
var gutil = require('gulp-util');

var helpers = {};
helpers.wrapAssertion= function(fn, done) {
  try {
    fn();
    done();
  } catch (e) {
    done(e);
  }
};
helpers.test = function (generator, done, extra, sampleFile, validateWith, logContent ) {

  logContent = logContent || false;

  var fixtures = path.join(__dirname, '../node_modules/raml2code-fixtures/');
  var sampleFiles = path.join(__dirname, '../node_modules/raml2code-fixtures/code-reference/');
  var raml2codeInstance = raml2code({generator: generator, extra: extra});
  var ramlPath = path.join(__dirname, '../node_modules/raml2code-fixtures/raml/index.raml');
  if(sampleFile !== undefined){
    var examplePath = sampleFiles + sampleFile;
    var exampleContents = fs.readFileSync(examplePath);
  }

  var ramlContents = fs.readFileSync(ramlPath);

  raml2codeInstance.write(new gutil.File({
    path: ramlPath,
    contents: ramlContents
  }));

  raml2codeInstance.on('data', function (file) {
    if (file.path == validateWith) {
      helpers.wrapAssertion(function () {
        file.isBuffer().should.equal(true);
        var content = file.contents.toString('utf8');
        if(logContent){
          console.log("=================" + file.path + "================")
          console.log(content);
          console.log("==================================================")
        }
        if(exampleContents !== undefined){
          exampleContents = exampleContents.toString('utf8').split('\n');
          content.split('\n').forEach(function (e, i) {
            e.trim().should.equal(exampleContents[i].trim(), "In line " + i + " " + sampleFile + " " + validateWith);
          });
        }
      }, done);
    }
  });

  raml2codeInstance.on('error', function (error) {
    console.log("error", error);
  });

};

module.exports = helpers;