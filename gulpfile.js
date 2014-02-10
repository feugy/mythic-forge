/**
 * Equivalent to makefile, with gulp.
 * The only requirement is to have gulp globally installed `npm install -g gulp`, 
 * and to have retrieved the npm dependencies with `npm install`
 *
 * Available tasks: 
 *   clean - removed hyperion/lib folder
 *   build - compiles coffee-script from hyperion/src to hyperion/lib 
 *   test - runs all tests with mocha (configuration in test/mocha.opts)
 *   dev (default) - clean, compiles coffee-script, and use watcher to recompile on the fly
 */
var _ = require('underscore');
var spawn = require('child_process').spawn;
var gulp = require('gulp');
var gutil = require('gulp-util');
var clean = require('gulp-clean');
var coffee = require('gulp-coffee');

var sources = 'hyperion/src/**/*.coffee';
var dest = 'hyperion/lib';
var isWin = process.platform.match(/^win/) != null;

gulp.task('clean', function(){
  return gulp.src(dest, {read: false})
    .pipe(clean());
});

function build() {
  return gulp.src(sources)
    .pipe(coffee({bare: true})
      .on('error', gutil.log))
      .on('error', gutil.beep)
    .pipe(gulp.dest(dest));
}

gulp.task('build', function(){
  return build()
});
gulp.task('cleanBuild', ['clean'], function(){
  return build()
});

gulp.task('test', function(callback){
  var cmd = "mocha"
  if (isWin) {
    cmd += '.cmd';
  }
  spawn(cmd, [], {
    stdio:'inherit', 
    env: _.extend({}, process.env, {NODE_ENV:"test"})
  }).on('exit', function(code) {
    if (callback) {
      callback(code === 0 ? null : code);
    } else {
      process.exit(code);
    }
  });
});

gulp.task('dev', ['cleanBuild'], function(){
  return gulp.watch(sources, ['build']);
});

gulp.task('default', ['dev']);
