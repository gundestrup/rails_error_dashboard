# Documentation Index

Complete guide to all documentation available for Rails Error Dashboard.

## 🚀 Getting Started

1. **[README.md](README.md)** - Start here! Installation, features, basic usage
2. **[INSTALLATION.md](INSTALLATION.md)** - Detailed installation guide (if you need more help)

## 📱 Integration Guides

### Mobile & Frontend
- **[MOBILE_APP_INTEGRATION.md](MOBILE_APP_INTEGRATION.md)** - React Native, Expo, Flutter integration
  - Step-by-step setup for mobile error reporting
  - Example code for React Native, Expo
  - API endpoint usage
  - Platform detection setup

### Notifications
- **[NOTIFICATION_CONFIGURATION.md](NOTIFICATION_CONFIGURATION.md)** - Multi-channel notifications
  - Slack integration
  - Email setup
  - Discord webhooks
  - PagerDuty for critical errors
  - Custom webhooks

## 🔧 Advanced Features

### Batch Operations
- **[BATCH_OPERATIONS_GUIDE.md](BATCH_OPERATIONS_GUIDE.md)** - Bulk operations
  - Resolve multiple errors at once
  - Delete errors in bulk
  - API usage examples

### Plugin System
- **[PLUGIN_DEVELOPMENT_GUIDE.md](PLUGIN_DEVELOPMENT_GUIDE.md)** - Extend functionality
  - Create custom plugins
  - Built-in plugin examples (Jira, metrics, audit logging)
  - Plugin API reference
  - Event hooks

## 🗄️ Database & Deployment

### Separate Database
- **[MIGRATION_TO_SEPARATE_DATABASE.md](MIGRATION_TO_SEPARATE_DATABASE.md)** - Production setup
  - Why use a separate database
  - Step-by-step migration guide
  - Performance considerations
  - Rollback instructions

### Multi-Version Testing
- **[MULTI_VERSION_TESTING.md](MULTI_VERSION_TESTING.md)** - For contributors/maintainers
  - Testing across Rails 7.0-8.0
  - Testing across Ruby 3.2-3.3
  - Local testing guide
  - CI configuration explained

## 🐛 Troubleshooting

### CI Issues
- **[CI_TROUBLESHOOTING.md](CI_TROUBLESHOOTING.md)** - For contributors fixing CI
  - Complete guide to all 7 CI issues we encountered
  - Root cause analysis for each
  - Detailed solutions with code
  - Key learnings and best practices
  - References to GitHub issues and blog posts

### Common Issues
Check README.md troubleshooting section for user-facing issues.

## 📋 Quick Reference

| I want to...                          | Read this document                                        |
|---------------------------------------|-----------------------------------------------------------|
| Install the gem                       | [README.md](README.md)                                    |
| Track mobile app errors               | [MOBILE_APP_INTEGRATION.md](MOBILE_APP_INTEGRATION.md)    |
| Set up Slack notifications            | [NOTIFICATION_CONFIGURATION.md](NOTIFICATION_CONFIGURATION.md) |
| Bulk delete errors                    | [BATCH_OPERATIONS_GUIDE.md](BATCH_OPERATIONS_GUIDE.md)    |
| Create a custom plugin                | [PLUGIN_DEVELOPMENT_GUIDE.md](PLUGIN_DEVELOPMENT_GUIDE.md)|
| Use separate database                 | [MIGRATION_TO_SEPARATE_DATABASE.md](MIGRATION_TO_SEPARATE_DATABASE.md) |
| Test on different Rails versions      | [MULTI_VERSION_TESTING.md](MULTI_VERSION_TESTING.md)      |
| Fix CI failures                       | [CI_TROUBLESHOOTING.md](CI_TROUBLESHOOTING.md)            |

## 📚 Documentation Organization

```
rails_error_dashboard/
├── README.md                          # Main documentation (start here)
│
├── User Guides/
│   ├── MOBILE_APP_INTEGRATION.md     # Mobile/frontend error reporting
│   ├── NOTIFICATION_CONFIGURATION.md  # Slack, Email, Discord, PagerDuty
│   ├── BATCH_OPERATIONS_GUIDE.md     # Bulk operations
│   └── PLUGIN_DEVELOPMENT_GUIDE.md   # Custom plugins
│
├── Operations & Deployment/
│   ├── MIGRATION_TO_SEPARATE_DATABASE.md  # Production database setup
│   ├── MULTI_VERSION_TESTING.md           # Version compatibility
│   └── CI_TROUBLESHOOTING.md              # CI issues & solutions
│
└── DOCUMENTATION_INDEX.md            # This file
```

## 🎯 By Use Case

### For End Users
1. Read [README.md](README.md)
2. Check [MOBILE_APP_INTEGRATION.md](MOBILE_APP_INTEGRATION.md) if using mobile
3. Set up [NOTIFICATION_CONFIGURATION.md](NOTIFICATION_CONFIGURATION.md)

### For Developers/Contributors
1. Read [README.md](README.md)
2. Review [MULTI_VERSION_TESTING.md](MULTI_VERSION_TESTING.md)
3. If CI fails, check [CI_TROUBLESHOOTING.md](CI_TROUBLESHOOTING.md)

### For Operations/DevOps
1. Read [README.md](README.md)
2. Review [MIGRATION_TO_SEPARATE_DATABASE.md](MIGRATION_TO_SEPARATE_DATABASE.md)
3. Set up [NOTIFICATION_CONFIGURATION.md](NOTIFICATION_CONFIGURATION.md)

### For Plugin Developers
1. Read [README.md](README.md)
2. Follow [PLUGIN_DEVELOPMENT_GUIDE.md](PLUGIN_DEVELOPMENT_GUIDE.md)

## 💡 Tips

- **Start with README.md** - It has everything you need for basic usage
- **Documentation is searchable** - Use Cmd/Ctrl+F to find specific topics
- **Examples included** - All guides include working code examples
- **Links are cross-referenced** - Related topics link to each other

## 🤝 Contributing to Documentation

Found an issue or want to improve docs?

1. Check if the topic fits in existing documents
2. Follow the same format and style
3. Include code examples
4. Cross-reference related topics
5. Submit a PR

See [README.md#contributing](README.md#-contributing) for full guidelines.
