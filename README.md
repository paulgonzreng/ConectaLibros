# 📚 ConectaLibros

![SQL Server](https://img.shields.io/badge/SQL_Server-CC2927?style=for-the-badge\&logo=microsoftsqlserver\&logoColor=white)
![T-SQL](https://img.shields.io/badge/T--SQL-CC2927?style=for-the-badge\&logo=microsoftsqlserver\&logoColor=white)

**ConectaLibros** is a relational database project developed with **Microsoft SQL Server and T-SQL** as part of my Systems Analysis studies.

The project models the relationship between **bookstores, publishers, authors, books and purchase requests**, with business rules enforced directly at the database level.

> This project focuses exclusively on **database design, implementation and security**. It does not include a graphical user interface.

---

## 🎯 Project Objectives

The main goal of the project was to design and implement a relational database capable of managing:

* Countries
* Authors
* Publishers
* Bookstores
* Books
* Purchase requests
* Books included in each request

The database also implements validation rules, controlled data access and user permissions.

---

## 🗃️ Database Model

The database contains the following main entities:

```text
Pais
Autor
Editorial
Libreria
Libros
Solicitud
Incluye
```

The `Incluye` table resolves the many-to-many relationship between books and purchase requests and stores the requested quantity.

---

## ⚙️ Implemented Features

### Database Design

* Relational database modeling
* Primary Keys
* Foreign Keys
* Composite Keys
* Unique indexes
* Referential integrity
* Business-rule validation

### T-SQL

* Stored Procedures
* Views
* `INSTEAD OF` Triggers
* Transactions
* Data validation
* Error handling
* Test data

### Security

The project also explores SQL Server security using:

* `LOGIN`
* `USER`
* Database roles
* `GRANT EXECUTE`
* Role-based permissions

Two application-oriented roles were implemented:

```text
RolLibreria
RolEditorial
```

---

## 📋 Business Rules

Some of the business rules modeled in the project include:

* Country codes must contain three letters.
* Authors must be at least 18 years old.
* An author's death date cannot precede their birth date.
* Bookstore RUT values must contain 12 digits.
* Usernames must be unique within the system.
* Passwords must satisfy minimum complexity requirements.
* ISBN values must contain 13 digits.
* Book stock cannot be negative.
* Delivery dates must be at least 24 hours after the request date.
* Requested quantities must be greater than zero.
* Requests can only include books with available stock.

---

## 🧪 Validation Testing

The original academic project includes test data designed to verify both successful operations and database validation rules.

Some tests intentionally attempt invalid operations in order to confirm that constraints and business rules are correctly enforced.

---

## 📈 Project Evolution

The original academic submission received **46/50**.

This repository begins with that original submitted version so the development history remains visible.

After instructor review, the project is being progressively refactored to improve:

* Constraint placement
* System-wide username validation
* Login and database-user synchronization
* Trigger design
* Removal of redundant validations
* Business-rule enforcement
* Code maintainability

These improvements will be incorporated through separate Git commits so the evolution of the project can be followed through the repository history.

---

## 🛠️ Technologies

* Microsoft SQL Server
* T-SQL
* SQL Server Management Studio
* Draw.io for database modeling

---

## 📂 Repository Structure

```text
ConectaLibros/
│
├── ConectaLibros.sql
├── README.md
│
└── docs/
    ├── ERD
    └── Business Rules & Relational Model
```

> Database design documentation will be added to the `docs` directory in subsequent commits.

---

## 👨‍💻 Author

**Paul González**
Systems Analyst Student · Junior .NET Developer
Montevideo, Uruguay 🇺🇾

[GitHub](https://github.com/paulgonzreng) · [LinkedIn](https://www.linkedin.com/in/paulgonzreng/)
