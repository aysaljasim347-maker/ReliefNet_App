const request = require('supertest');
const express = require('express');
const bodyParser = require('body-parser');

// Mock dependencies
const db = require('../src/config/db');
const { createNotification } = require('../src/utils/notify');

jest.mock('../src/config/db');
jest.mock('../src/utils/notify');
jest.mock('../src/middleware/auth', () => (role) => (req, res, next) => {
    req.user = { id: 1, role: 'donor' };
    next();
});

const app = express();
app.use(bodyParser.json());

// Mock res.success/fail
app.use((req, res, next) => {
    res.success = (data, code = 200) => res.status(code).json({ success: true, data });
    res.fail = (error, code = 400) => {
        console.log('Test Fail:', error);
        res.status(code).json({ success: false, error });
    };
    next();
});

const inKindRoutes = require('../src/modules/in_kind/routes');
app.use('/api/in-kind', inKindRoutes);

// Also mock next(e) to see errors
app.use((err, req, res, next) => {
    console.log('Test Global Error:', err.message);
    res.status(500).json({ success: false, error: err.message });
});

describe('In-Kind Optimization Test', () => {
    let mockClient;

    beforeEach(() => {
        jest.clearAllMocks();
        mockClient = {
            query: jest.fn(),
            release: jest.fn(),
        };
        db.connect.mockResolvedValue(mockClient);
    });

    test('POST /api/in-kind/my/:dId/requests/:rId/approve notifies rejected beneficiaries in parallel', async () => {
        // Mock all queries in order
        mockClient.query
            .mockResolvedValueOnce({ command: 'BEGIN' }) // 1. BEGIN
            .mockResolvedValueOnce({ // 2. Donation query
                rows: [{
                    id: 10,
                    title: 'Test Item',
                    donor_name: 'Donor',
                    donor_email: 'donor@test.com',
                    donor_phone: '123456',
                    status: 'available'
                }]
            })
            .mockResolvedValueOnce({ // 3. Request query
                rows: [{ id: 100, beneficiary_user_id: 200, status: 'pending' }]
            })
            .mockResolvedValueOnce({ command: 'UPDATE' }) // 4. Update approved
            .mockResolvedValueOnce({ command: 'UPDATE' }) // 5. Update others
            .mockResolvedValueOnce({ command: 'UPDATE' }) // 6. Update donation
            .mockResolvedValueOnce({ command: 'COMMIT' }); // 7. COMMIT

        // 8. Mock rejected beneficiaries query (2 rejected) - this uses db.query directly
        db.query.mockResolvedValueOnce({
            rows: [
                { beneficiary_id: 301 },
                { beneficiary_id: 302 }
            ]
        });

        const res = await request(app).post('/api/in-kind/my/10/requests/100/approve');

        if (res.status !== 200) {
            console.log('Error Response Body:', res.body);
        }

        expect(res.status).toBe(200);
        expect(res.body.success).toBe(true);

        // Verify approved notification
        expect(createNotification).toHaveBeenCalledWith(
            200,
            'Your request was approved!',
            expect.stringContaining('Test Item'),
            'in_kind_approved',
            expect.any(Object)
        );

        // Verify rejected notifications (N+1 fixed via Promise.all)
        expect(createNotification).toHaveBeenCalledWith(
            301,
            'Request not selected',
            expect.stringContaining('Test Item'),
            'in_kind_rejected',
            { donation_id: 10 }
        );
        expect(createNotification).toHaveBeenCalledWith(
            302,
            'Request not selected',
            expect.stringContaining('Test Item'),
            'in_kind_rejected',
            { donation_id: 10 }
        );

        expect(createNotification).toHaveBeenCalledTimes(3);
    });
});
