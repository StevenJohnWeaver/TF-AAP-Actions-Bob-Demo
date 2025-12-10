# Test Event Stream Endpoint

Quick guide to verify the EDA event stream endpoint is accessible.

---

## Test the Event Stream Endpoint

### Step 1: Verify Event Stream Exists

1. **Log in to EDA Controller**
   - Go to: `https://sandbox-aap-steveweaver-hashi-dev.apps.rm2.thpm.p1.openshiftapps.com/`
   - Click **"Event-Driven Ansible"**

2. **Check Event Streams**
   - Go to **"Event Streams"**
   - Verify `terraform-infrastructure-events` exists
   - Check if it's **Enabled**

### Step 2: Test the POST Endpoint

```bash
# Set your credentials
EDA_USERNAME="your-username"
EDA_PASSWORD="your-password"
AAP_HOST="https://sandbox-aap-steveweaver-hashi-dev.apps.rm2.thpm.p1.openshiftapps.com"
EVENT_STREAM_NAME="terraform-infrastructure-events"

# Test the endpoint
curl -X POST \
  -u "$EDA_USERNAME:$EDA_PASSWORD" \
  -H "Content-Type: application/json" \
  -d '{
    "source": "terraform",
    "event_type": "test",
    "timestamp": "2024-12-10T19:30:00Z",
    "data": {
      "message": "Test event"
    }
  }' \
  "$AAP_HOST/api/eda/v1/event-streams/$EVENT_STREAM_NAME/post/"
```

### Expected Results:

**✅ Success (201 Created)**:
```json
{
  "id": "...",
  "status": "received"
}
```

**❌ 404 Not Found**:
```html
<!doctype html>
<html lang="en">
<head>
  <title>Not Found</title>
</head>
```

---

## Common Issues

### Issue 1: Event Stream Doesn't Exist

**Check:**
```bash
# List all event streams
curl -u "$EDA_USERNAME:$EDA_PASSWORD" \
  "$AAP_HOST/api/eda/v1/event-streams/"
```

**Solution**: Create the event stream in EDA Controller

### Issue 2: Wrong API Path (AAP 2.5+)

The API path might be different. Try these alternatives:

```bash
# Option 1: Without /api prefix
curl -X POST \
  -u "$EDA_USERNAME:$EDA_PASSWORD" \
  -H "Content-Type: application/json" \
  -d '{"source":"terraform","event_type":"test"}' \
  "$AAP_HOST/eda/v1/event-streams/$EVENT_STREAM_NAME/post/"

# Option 2: With /api/gateway prefix
curl -X POST \
  -u "$EDA_USERNAME:$EDA_PASSWORD" \
  -H "Content-Type: application/json" \
  -d '{"source":"terraform","event_type":"test"}' \
  "$AAP_HOST/api/gateway/eda/v1/event-streams/$EVENT_STREAM_NAME/post/"

# Option 3: Direct to event stream ID
curl -X POST \
  -u "$EDA_USERNAME:$EDA_PASSWORD" \
  -H "Content-Type: application/json" \
  -d '{"source":"terraform","event_type":"test"}' \
  "$AAP_HOST/api/eda/v1/event-streams/1/post/"
```

### Issue 3: Authentication Method

Try using token authentication instead:

```bash
# Get a token first
TOKEN=$(curl -X POST \
  -H "Content-Type: application/json" \
  -d "{\"username\":\"$EDA_USERNAME\",\"password\":\"$EDA_PASSWORD\"}" \
  "$AAP_HOST/api/eda/v1/auth/login/" | jq -r '.token')

# Use token for POST
curl -X POST \
  -H "Authorization: Bearer $TOKEN" \
  -H "Content-Type: application/json" \
  -d '{"source":"terraform","event_type":"test"}' \
  "$AAP_HOST/api/eda/v1/event-streams/$EVENT_STREAM_NAME/post/"
```

---

## Find the Correct Endpoint

### Method 1: Check EDA API Documentation

```bash
# Get API schema
curl -u "$EDA_USERNAME:$EDA_PASSWORD" \
  "$AAP_HOST/api/eda/v1/schema/"
```

### Method 2: Check Event Stream Details in UI

1. Go to EDA Controller → Event Streams
2. Click on `terraform-infrastructure-events`
3. Look for "POST URL" or "Webhook URL" in the details
4. Use that exact URL

### Method 3: Check Browser Network Tab

1. Open EDA Controller in browser
2. Open Developer Tools (F12)
3. Go to Network tab
4. Navigate to Event Streams
5. Look at the API calls to see the correct path

---

## Update Terraform Configuration

Once you find the correct endpoint, update `terraform/main.tf`:

```hcl
action "aap_eda_eventstream_post" "infrastructure_ready" {
  config {
    limit             = "all"
    template_type     = "job"
    job_template_name = "Configure AWS Infrastructure"
    organization_name = "Default"
    event_stream_config = {
      username = var.eda_event_stream_username
      password = var.eda_event_stream_password
      url      = "CORRECT_URL_HERE"  # Update this
    }
  }
}
```

---

## Alternative: Use Webhook Instead

If the event stream POST endpoint continues to have issues, you can use the webhook approach:

1. **Update rulebook** to use `ansible.eda.webhook` source
2. **Expose webhook** via OpenShift route
3. **Update Terraform action** to POST to webhook URL

This was discussed earlier but we kept event stream for the demo. If needed, we can switch to this approach.

---

**Made with Bob** 🤖