from read_write_postings import insert_posting


def test_insert_posting():
    test_data = {
        "Sender": "Alice",
        "name": "Cool Place",
        "time_posted": "2025-04-24T15:30:00",
        "photo_id": "abc123",
        "category": "parks",
        "address": "123 Main St",
        "external_url": "http://example.com",
        "status": "active",
        "longitude": 13.405,
        "latitude": 52.52,
    }
    print(insert_posting(test_data))
