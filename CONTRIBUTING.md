# Contributing to SWD-085 Web Portal

First off, thank you for considering contributing to the Swordsmen Virtual Squadron web portal! This document outlines the rules and workflows we follow to ensure a smooth, professional, and collaborative development environment.

## 🚨 Code of Conduct
- Be respectful and constructive in all communications.
- We are here to learn, collaborate, and build a high-quality tool for the community.
- **No toxicity or elitism.** We value humility and continuous learning.

## 🛡️ Branch Protection & Workflow
**The `main` branch is protected.** Direct pushes to `main` are strictly forbidden. 

All work must follow this Pull Request (PR) workflow:
1. **Pick an Issue:** Go to the "Issues" tab and assign yourself a task that matches your skills.
2. **Create a Branch:** Create a new branch from `main` using our naming convention (see below).
3. **Develop:** Write your code, commit your changes using standard conventions.
4. **Push:** Push your branch to GitHub.
5. **Open a PR:** Create a Pull Request against `main`. 
6. **Review:** A project leader (Cami) or a designated reviewer must approve your PR.
7. **Merge:** Once approved and tests pass, the PR will be merged.

## 🌿 Git Conventions (Global Standards)

### Branch Naming
Use the following format: `<type>/<short-description>`
- `feature/` for new features (e.g., `feature/recruitment-form`)
- `fix/` for bug fixes (e.g., `fix/navbar-overlay`)
- `docs/` for documentation (e.g., `docs/update-readme`)
- `refactor/` for code restructuring (e.g., `refactor/api-endpoints`)

### Commit Messages (Conventional Commits)
We follow the Conventional Commits specification. This helps us generate changelogs and understand the project history.
Format: `<type>: <description>`
- `feat:` A new feature (e.g., `feat: add event registration form`)
- `fix:` A bug fix (e.g., `fix: correct timezone offset in events API`)
- `docs:` Documentation only changes
- `style:` Changes that do not affect the meaning of the code (white-space, formatting)
- `refactor:` A code change that neither fixes a bug nor adds a feature
- `test:` Adding missing tests or correcting existing tests
- `chore:` Changes to the build process or auxiliary tools

## 💻 Coding Standards

### Language
- **English Only:** All code (variables, functions, classes, comments) MUST be written in English.
- **Documentation & Issues:** GitHub Issues, Pull Requests, and external documentation can be in Spanish to facilitate communication within the team.

### Frontend (HTML/CSS/JS)
- **BEM Methodology:** All CSS classes must follow the BEM (Block Element Modifier) naming convention and be prefixed with `swd-`. 
  - Example: `.swd-header`, `.swd-header__logo`, `.swd-header__logo--active`.
- **Semantic HTML:** Use proper HTML5 tags (`<header>`, `<main>`, `<section>`, `<article>`, `<footer>`).
- **Images:** Do NOT use `background-image` for content images. Use the `<picture>` or `<img>` tags to ensure accessibility and ease of content management.
- **Accessibility:** Ensure all interactive elements have `aria-*` attributes and proper contrast.

### Backend (Python / SQL)
- Follow PEP 8 guidelines for Python.
- Write clear, documented functions (docstrings).
- Database changes must be reviewed before execution.

## 🧪 Quality Assurance & Testing
- **No Broken Code:** Ensure your code runs locally before pushing.
- **Testing:** Backend endpoints must be tested (using tools like Postman or automated tests) before opening a PR.
- **No AI "Copy-Paste":** If you use AI to help write code, you MUST understand what the code does. Reviewers will ask you to explain your logic.

## 🛠️ Issue Management
- Do not work on issues that are not assigned to you.
- If you can't finish an issue, unassign yourself and leave a comment so someone else can pick it up.
- Update the GitHub Project board: Move your issue to "In Progress" when you start, and "Review" when you open the PR.
