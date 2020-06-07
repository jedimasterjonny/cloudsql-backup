const {google} = require('googleapis');
const {auth} = require('google-auth-library');
const sql = google.sql('v1beta4');

const project = process.env.PROJECT;
const instance = process.env.INSTANCE;
const bucket = process.env.BUCKET;
const db = process.env.DB;

exports.exportDatabase = (_req, res) => {
  async function doIt() {
    const authRes = await auth.getApplicationDefault();
    const authClient = authRes.credential;
    const request = {
      project: `${project}`,
      instance: `${instance}`,
      resource: {
        exportContext: {
          kind: 'sql#exportContext',
          fileType: 'SQL',
          uri: `gs://${bucket}/backup-${Date.now()}.gz`,
          databases: [`${db}`],
        },
      },
      auth: authClient,
    };

    sql.instances.export(request, function(err, result) {
      if (err) {
        console.log(err);
      } else {
        console.log(result);
      }
      res.status(200).send('Command completed', err, result);
    });
  }
  doIt();
};
