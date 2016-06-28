// Generated by CoffeeScript 1.10.0
var db, log, querystring, thumb;

db = require('../helpers/db_connect_helper').db_connect();

thumb = require('../lib/thumb');

querystring = require('querystring');

log = require('printit')({
  prefix: 'binary'
});

module.exports.addBinary = function(doc, attachData, readStream, callback) {
  var attachFile, binary, name, ref;
  name = attachData.name;
  attachFile = function(binary, cb) {
    var stream;
    attachData.name = querystring.escape(name);
    stream = db.saveAttachment(binary, attachData, function(err, binDoc) {
      var bin, binList;
      if (err) {
        return log.error("" + (JSON.stringify(err)));
      } else {
        log.info("Binary " + name + " stored in Couchdb");
        bin = {
          id: binDoc.id,
          rev: binDoc.rev
        };
        binList = doc.binary || {};
        binList[name] = bin;
        return db.merge(doc._id, {
          binary: binList
        }, function(err) {
          if (err != null) {
            log.error(err);
          }
          return cb();
        });
      }
    });
    if (readStream.headers) {
      delete readStream.headers['content-disposition'];
    }
    return readStream.pipe(stream);
  };
  if (((ref = doc.binary) != null ? ref[name] : void 0) != null) {
    return db.get(doc.binary[name].id, function(err, binary) {
      return attachFile(binary, function() {
        callback();
        if (doc.docType.toLowerCase() === 'file' && doc["class"] === 'image' && name === 'file') {
          return thumb.create(doc.id, true);
        }
      });
    });
  } else {
    binary = {
      docType: "Binary"
    };
    return db.save(binary, function(err, binary) {
      return attachFile(binary, callback);
    });
  }
};
