#!/usr/bin/env node
const fs = require('fs');
const path = require('path');

const SCHEMAS_DIR = path.join(__dirname, 'schemas');
const OUTPUT_DIR = path.join(__dirname, '..', 'desktop-client', 'lib', 'models');

const SCHEMA_FILES = [
  'task.json', 'project.json', 'note.json', 'message.json', 'user.json', 'membership.json',
];

function toCamelCase(s) {
  return s.replace(/_([a-z])/g, (_, c) => c.toUpperCase());
}

function toPascalCase(s) {
  const c = toCamelCase(s);
  return c.charAt(0).toUpperCase() + c.slice(1);
}

function singularize(s) {
  return s.endsWith('s') ? s.slice(0, -1) : s;
}

function resolveRawType(prop) {
  const t = prop.type;
  if (Array.isArray(t)) return t.find((x) => x !== 'null');
  return t;
}

function isNullable(fieldName, prop, requiredFields) {
  const t = prop.type;
  if (Array.isArray(t) && t.includes('null')) return true;
  return !requiredFields.includes(fieldName);
}

function resolveDartType(fieldName, prop, requiredFields, parentClass) {
  const nullable = isNullable(fieldName, prop, requiredFields);
  const raw = resolveRawType(prop);

  let dartType;
  if (prop.enum) {
    dartType = `${parentClass}${toPascalCase(fieldName)}`;
  } else if (raw === 'array' && prop.items?.type === 'object') {
    dartType = `List<${parentClass}${toPascalCase(singularize(fieldName))}>`;
  } else {
    switch (raw) {
      case 'string': dartType = 'String'; break;
      case 'integer': dartType = 'int'; break;
      case 'number': dartType = 'double'; break;
      case 'boolean': dartType = 'bool'; break;
      default: dartType = 'String';
    }
  }

  return nullable ? `${dartType}?` : dartType;
}

function buildClass(className, schemaDef, enumDefs, extraClasses) {
  const props = schemaDef.properties || {};
  const required = schemaDef.required || [];

  const requiredEntries = Object.entries(props).filter(([k]) => required.includes(k));
  const optionalEntries = Object.entries(props).filter(([k]) => !required.includes(k));
  const orderedEntries = [...requiredEntries, ...optionalEntries];

  const fields = [];
  const ctorParams = [];
  const fromJsonLines = [];
  const toJsonLines = [];

  for (const [fieldName, prop] of orderedEntries) {
    const camel = toCamelCase(fieldName);
    const req = required.includes(fieldName);
    const nullable = isNullable(fieldName, prop, required);
    const raw = resolveRawType(prop);
    const dartType = resolveDartType(fieldName, prop, required, className);

    if (prop.enum) {
      const enumName = `${className}${toPascalCase(fieldName)}`;
      enumDefs.push(`enum ${enumName} { ${prop.enum.join(', ')} }`);
      fields.push(`  final ${dartType} ${camel};`);
      ctorParams.push(`    ${req ? 'required ' : ''}this.${camel},`);
      if (nullable) {
        fromJsonLines.push(
          `    ${camel}: json['${fieldName}'] == null ? null` +
          ` : ${enumName}.values.firstWhere((e) => e.name == json['${fieldName}'] as String),`,
        );
        toJsonLines.push(`      '${fieldName}': ${camel}?.name,`);
      } else {
        fromJsonLines.push(
          `    ${camel}: ${enumName}.values.firstWhere((e) => e.name == json['${fieldName}'] as String),`,
        );
        toJsonLines.push(`      '${fieldName}': ${camel}.name,`);
      }
    } else if (raw === 'array' && prop.items?.type === 'object') {
      const itemClass = `${className}${toPascalCase(singularize(fieldName))}`;
      const nestedEnums = [];
      extraClasses.push(buildClass(itemClass, prop.items, nestedEnums, []));
      enumDefs.push(...nestedEnums);

      fields.push(`  final ${dartType} ${camel};`);
      ctorParams.push(`    ${req ? 'required ' : ''}this.${camel},`);
      if (nullable) {
        fromJsonLines.push(
          `    ${camel}: (json['${fieldName}'] as List<dynamic>?)` +
          `?.map((e) => ${itemClass}.fromJson(e as Map<String, dynamic>)).toList(),`,
        );
        toJsonLines.push(`      '${fieldName}': ${camel}?.map((e) => e.toJson()).toList(),`);
      } else {
        fromJsonLines.push(
          `    ${camel}: (json['${fieldName}'] as List<dynamic>)` +
          `.map((e) => ${itemClass}.fromJson(e as Map<String, dynamic>)).toList(),`,
        );
        toJsonLines.push(`      '${fieldName}': ${camel}.map((e) => e.toJson()).toList(),`);
      }
    } else {
      fields.push(`  final ${dartType} ${camel};`);
      ctorParams.push(`    ${req ? 'required ' : ''}this.${camel},`);
      fromJsonLines.push(`    ${camel}: json['${fieldName}'] as ${dartType},`);
      toJsonLines.push(`      '${fieldName}': ${camel},`);
    }
  }

  return [
    `class ${className} {`,
    `  const ${className}({`,
    ...ctorParams,
    `  });`,
    ``,
    `  factory ${className}.fromJson(Map<String, dynamic> json) => ${className}(`,
    ...fromJsonLines,
    `  );`,
    ``,
    ...fields,
    ``,
    `  Map<String, dynamic> toJson() => <String, dynamic>{`,
    ...toJsonLines,
    `  };`,
    `}`,
  ].join('\n');
}

function generateDartFile(schema) {
  const className = toPascalCase(schema.$id);
  const enumDefs = [];
  const extraClasses = [];
  const mainClass = buildClass(className, schema, enumDefs, extraClasses);

  const parts = [
    '// GENERATED — do not edit by hand. Run: node shared-models/generate.js',
    '// ignore_for_file: lines_longer_than_80_chars, public_member_api_docs',
    '',
    ...enumDefs,
    ...(enumDefs.length ? [''] : []),
    ...extraClasses,
    ...(extraClasses.length ? [''] : []),
    mainClass,
    '',
  ];

  return parts.join('\n');
}

fs.mkdirSync(OUTPUT_DIR, { recursive: true });

const exported = [];
for (const schemaFile of SCHEMA_FILES) {
  const schema = JSON.parse(fs.readFileSync(path.join(SCHEMAS_DIR, schemaFile), 'utf8'));
  const code = generateDartFile(schema);
  const outPath = path.join(OUTPUT_DIR, `${schema.$id}.dart`);
  fs.writeFileSync(outPath, code);
  exported.push(schema.$id);
  console.log(`generated: desktop-client/lib/models/${schema.$id}.dart`);
}

const barrel = [
  '// GENERATED — do not edit by hand. Run: node shared-models/generate.js',
  ...exported.map((id) => `export '${id}.dart';`),
  '',
].join('\n');
fs.writeFileSync(path.join(OUTPUT_DIR, 'models.dart'), barrel);
console.log('generated: desktop-client/lib/models/models.dart');
