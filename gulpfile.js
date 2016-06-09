/**
 * Equivalent to makefile, with gulp.
 * The only requirement is to have gulp globally installed `npm install -g gulp`,
 * and to have retrieved the npm dependencies with `npm install`
 *
 * Available tasks:
 *   clean - removed hyperion/lib folder
 *   build - compiles coffee-script from hyperion/src to hyperion/lib
 *   cleanBuild - clean and then build tasks
 *   test - runs all tests with mocha (configuration in test/mocha.opts)
 *   deploy - compile, minify and make production ready version of rheia administration client
 *   watch (default) - clean, compiles coffee-script, and use watcher to recompile on the fly
 */
var spawn = require('child_process').spawn;
var gulp = require('gulp');
var gutil = require('gulp-util');
var del = require('del');
var stylus = require('gulp-stylus');
var coffee = require('gulp-coffee');
var plumber = require('gulp-plumber');
var requirejs = require('requirejs');
var async = require('async');
var fs = require('fs-extra');
var join = require('path').join;

var sources = 'hyperion/src/**/*.coffee';
var dest = 'hyperion/lib';
var isWin = process.platform.match(/^win/) != null;

gulp.task('default', ['watch']);

// remove hyperion/lib folder
gulp.task('clean', function(){
  return del([dest]);
});

function build() {
  return gulp.src(sources)
    .pipe(plumber({
      errorHandler: function(err) {
        gutil.log(err);
        gutil.beep();
      }
    }))
    .pipe(coffee({bare: true}))
    .pipe(gulp.dest(dest));
}

// Build hyperion coffee sources
gulp.task('build', function(){
  return build()
});
gulp.task('cleanBuild', ['clean'], function(){
  return build()
});

// Run all tests
gulp.task('test', ['cleanBuild'], function(callback){
  var cmd = "mocha"
  if (isWin) {
    cmd += '.cmd';
  }
  spawn(cmd, [], {
    stdio:'inherit',
    env: Object.assign({}, process.env, {NODE_ENV:"test"})
  }).on('exit', function(code) {
    if (callback) {
      callback(code === 0 ? null : code);
    } else {
      process.exit(code);
    }
  });
});

// Clean, build, and then watch for coffee files changes (default)
gulp.task('watch', ['cleanBuild'], function(){
  return gulp.watch(sources, ['build']);
});

// Compile Rheia coffee and stylus sources, minify requirejs files
var deployTarget = 'rheia-min';
var deployTemp = 'rheia-build';

// clean previous build output
gulp.task('deploy-clean', function() {
  return del([deployTarget]);
});
// copy source into temporary folder
gulp.task('deploy-copySource', ['deploy-clean'], function() {
  return gulp.src('rheia/**', {base:"./rheia/"})
    .pipe(gulp.dest(deployTarget));
});
// compile coffee scripts
gulp.task('deploy-compileCoffee', ['deploy-copySource'], function() {
  return gulp.src(deployTarget+'/**/*.coffee')
    .pipe(coffee({bare: true})
      .on('error', gutil.log))
    .pipe(gulp.dest(deployTarget));
});
// compile stylus style sheet
gulp.task('deploy-compileStylus', ['deploy-copySource'], function() {
  return gulp.src(deployTarget+'/style/rheia.styl')
    .pipe(stylus({set:['compress']})
      .on('error', gutil.log))
    .pipe(gulp.dest(deployTarget+'/style'));
});
// minify with requireJS optimizer
gulp.task('deploy-minify', ['deploy-compileCoffee', 'deploy-compileStylus'], function(end) {
  var config = {
    appDir: deployTarget,
    dir: deployTemp,
    baseUrl: './src/',
    mainConfigFile: deployTarget + '/src/Router.js',
    optimizeCss: 'standard',
    preserveLicenseComments: false,
    locale: null,
    optimize: 'uglify2',
    useStrict: true,
    modules: [{
      name: 'Router'
    }]
  };
  requirejs.optimize(config, function(err) {
    end(err instanceof Error ? err : null);
  });
});
// deploy task
gulp.task('deploy', ['deploy-minify'], function(end) {
  // move into a timestamp folder and replace links to make page cacheable
  var timestamp = new Date().getTime().toString();
  var timestamped = join(deployTarget, timestamp);
  var index = join(deployTarget, 'index.html');
  fs.remove(deployTarget, function(err) {
    if (err) {
      return end(err);
    }
    fs.mkdirs(deployTarget, function(err) {
      if (err) {
        return end(err);
      }
      fs.rename(deployTemp, timestamped, function(err) {
        if (err) {
          return end(err);
        }
        fs.rename(join(timestamped, 'index.html'), index, function(err) {
          if (err) {
            return end(err);
          }
          // replaces links from main html file
          fs.readFile(index, 'utf8', function(err, content) {
            if (err) {
              return end(err);
            }
            specs = [{
              pattern: /<\s*script([^>]*)data-main\s*=\s*(["'])(.*(?=\2))\2([^>]*)src\s*=\s*(["'])(.*(?=\5))\5/gi,
              replace: '<script$1data-main="' + timestamp + '/$3"$4src="' + timestamp + '/$6"'
            },{
              pattern: /<\s*script([^>]*)src\s*=\s*(["'])(.*(?=\2))\2([^>]*)data-main\s*=\s*(["'])(.*(?=\5))\5/gi,
              replace: '<script$1src="' + timestamp + '/$3"$4data-main="' + timestamp + '/$6"'
            },{
              pattern: /<\s*link([^>]*)href\s*=\s*(["'])(.*(?=\2))\2/gi,
              replace: '<link$1href="' + timestamp + '/$3"'
            }];
            specs.forEach(function(spec) {
              content = content.replace(spec.pattern, spec.replace);
            });
            fs.writeFile(index, content, end);
          });
        });
      });
    });
  });
});