const PDFDocument = require('pdfkit');
const fs = require('fs');
const path = require('path');

async function generateDonationReceipt(donation) {
  return new Promise((resolve, reject) => {
    const doc = new PDFDocument({ margin: 50 });
    const fileName = `receipt_${donation.id}_${Date.now()}.pdf`;
    const filePath = path.join(__dirname, '../uploads/receipts', fileName);
    
    // Ensure dir exists
    fs.mkdirSync(path.dirname(filePath), { recursive: true });
    
    const stream = fs.createWriteStream(filePath);
    doc.pipe(stream);

    // Header
    doc.fontSize(20).text('ReliefNet Pakistan', { align: 'center' });
    doc.fontSize(14).text('Donation Receipt', { align: 'center' });
    doc.moveDown();
    
    // Receipt details
    doc.fontSize(12);
    doc.text(`Receipt No: DON-${donation.id.toString().padStart(6, '0')}`);
    doc.text(`Date: ${new Date(donation.verified_at || donation.created_at).toLocaleDateString('en-PK')}`);
    doc.moveDown();
    
    // Donor info
    doc.fontSize(14).text('Donor Information', { underline: true });
    doc.fontSize(12);
    doc.text(`Name: ${donation.donor_name || 'Anonymous'}`);
    doc.text(`Email: ${donation.donor_email || 'N/A'}`);
    doc.moveDown();
    
    // Donation details
    doc.fontSize(14).text('Donation Details', { underline: true });
    doc.fontSize(12);
    doc.text(`Campaign: ${donation.campaign_title}`);
    doc.text(`NGO: ${donation.org_name}`);
    doc.text(`Amount: PKR ${parseInt(donation.amount).toLocaleString()}`);
    doc.text(`Payment Method: ${donation.payment_method}`);
    doc.text(`Transaction ID: ${donation.transaction_id || 'N/A'}`);
    doc.moveDown();
    
    // Footer
    doc.fontSize(10).text('Thank you for your generous contribution.', { align: 'center' });
    doc.text('This is a computer-generated receipt.', { align: 'center' });
    
    doc.end();
    
    stream.on('finish', () => resolve(`/uploads/receipts/${fileName}`));
    stream.on('error', reject);
  });
}

module.exports = { generateDonationReceipt };