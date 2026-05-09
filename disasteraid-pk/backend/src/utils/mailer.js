const nodemailer = require('nodemailer');

const transporter = nodemailer.createTransport({
  service: 'gmail', // or your SMTP
  auth: {
    user: process.env.MAIL_USER,
    pass: process.env.MAIL_PASS,
  },
});

async function sendReceiptEmail(to, receiptPath, donation) {
  const mailOptions = {
    from: '"ReliefNet" <noreply@reliefnet.pk>',
    to,
    subject: `Donation Receipt - ${donation.campaign_title}`,
    html: `
      <h2>Thank you for your donation!</h2>
      <p>Dear ${donation.donor_name || 'Donor'},</p>
      <p>We've received your donation of <strong>PKR ${parseInt(donation.amount).toLocaleString()}</strong> 
         for "${donation.campaign_title}".</p>
      <p>Your receipt is attached to this email.</p>
      <p>Regards,<br>ReliefNet Team</p>
    `,
    attachments: [{
      filename: `receipt-${donation.id}.pdf`,
      path: receiptPath,
    }],
  };
  
  return transporter.sendMail(mailOptions);
}

module.exports = { sendReceiptEmail };