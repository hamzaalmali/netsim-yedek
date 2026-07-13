const nodemailer = require('nodemailer');

async function sendNotification({ senderEmail, appPassword, recipients, subject, text }) {
  const transporter = nodemailer.createTransport({
    service: 'gmail',
    auth: { user: senderEmail, pass: appPassword },
  });
  await transporter.sendMail({
    from: senderEmail,
    to: recipients,
    subject,
    text,
  });
}

module.exports = { sendNotification };
