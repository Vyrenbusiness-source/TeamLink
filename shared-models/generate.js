#!/usr/bin/env node
'use strict';

const fs = require('fs');
const path = require('path');

const SCHEMAS_DIR = path.join(__dirname, 'schemas');
const DART_OUT_DIR = path.join(__dirname, '..', 'desktop-client', 'lib', 'models');

function toCamel(s) {
  return s.replace(/_([a-z])/g, (_, c) => c.toUpperCase());
}

function toPascal(s) {
  const c = toCamel(s);
  return c[0].toUpperCase() + c.slice(1);
}

function dartBaseType(jsonType) {
  switch (jsonType) {
    case 'string':  return 'String';
    case 'integer': return 'int';
    case 'boolean': return 'bool';
    case 'number':  return 'double';
    default:        return 'dynamic';
  }
}

function resolveFieldInfo(propName, prop, className, requiredSet) {
  const isRequired = requiredSet.has(propName);
  const rawTypes = Array.isArray(prop.type) ? prop.type : [prop.type ?? 'string'];
  const isNullable = rawTypes.includes('null') || !isRequired;
  const baseTypes = rawTypes.filter((t) => t !== 'null');

  if (prop.enum) {
    const nonNull = prop.enum.filter((v) => v !== null);
    if (nonNull.length > 0) {
      const enumName = `${className}${toPascal(propName)}`;
      const dartType = isNullable ? `${enumName}?` : enumName;
      return { dartType, enumName, enumValues: nonNull };
    }
    return { dartType: 'String?', enumName: null, enumValues: [] };
  }

  const base = dartBaseType(baseTypes[0]);
  return { dartType: isNullable ? `${base}?` : base, enumName: null, enumValues: [] };
}

function generateDart(schema) {
  const id = schema.$id;
  const className = toPascal(id);
  const requiredSet = new Set(schema.required ?? []);
  const entries = Object.entries(schema.properties ?? {});

  const lines = [];
  lines.push('// GENERATED — do not edit by hand. Run: node shared-models/generate.js');
  lines.push('// ignore_for_file: lines_longer_than_80_chars, public_member_api_docs');
  lines.push('');
  lines.push("import 'package:freezed_annotation/freezed_annotation.dart';");
  lines.push('');
  lines.push(`part '${id}.freezed.dart';`);
  lines.push(`part '${id}.g.dart';`);
  lines.push('');

  // Enums before class
  for (const [propName, prop] of entries) {
    const info = resolveFieldInfo(propName, prop, className, requiredSet);
    if (info.enumName) {
      lines.push('@JsonEnum()');
      lines.push(`enum ${info.enumName} {`);
      for (const v of info.enumValues) {
        lines.push(`  ${toCamel(String(v))},`);
      }
      lines.push('}');
      lines.push('');
    }
  }

  // Freezed class
  lines.push('@freezed');
  lines.push(`abstract class ${className} with _$${className} {`);
  lines.push('  // ignore: invalid_annotation_target');
  lines.push('  @JsonSerializable(fieldRename: FieldRename.snake)');
  lines.push(`  const factory ${className}({`);

  const required = entries.filter(([n]) => requiredSet.has(n));
  const optional = entries.filter(([n]) => !requiredSet.has(n));
  for (const [propName, prop] of [...required, ...optional]) {
    const info = resolveFieldInfo(propName, prop, className, requiredSet);
    const isRequired = requiredSet.has(propName);
    const dartName = toCamel(propName);
    const req = isRequired ? 'required ' : '';
    lines.push(`    ${req}${info.dartType} ${dartName},`);
  }

  lines.push(`  }) = _${className};`);
  lines.push('');
  lines.push(`  factory ${className}.fromJson(Map<String, dynamic> json) =>`);
  lines.push(`      _$${className}FromJson(json);`);
  lines.push('}');

  return lines.join('\n') + '\n';
}

// ── Main ──────────────────────────────────────────────────────────────────────
if (!fs.existsSync(DART_OUT_DIR)) {
  fs.mkdirSync(DART_OUT_DIR, { recursive: true });
}

const schemaFiles = fs
  .readdirSync(SCHEMAS_DIR)
  .filter((f) => f.endsWith('.json'))
  .sort();

const exported = [];
for (const file of schemaFiles) {
  const schema = JSON.parse(fs.readFileSync(path.join(SCHEMAS_DIR, file), 'utf8'));
  const dart = generateDart(schema);
  const outPath = path.join(DART_OUT_DIR, `${schema.$id}.dart`);
  fs.writeFileSync(outPath, dart, 'utf8');
  console.log(`  generated: ${schema.$id}.dart`);
  exported.push(schema.$id);
}

// Barrel file
const barrel = [
  '// GENERATED — do not edit by hand. Run: node shared-models/generate.js',
  ...exported.map((id) => `export '${id}.dart';`),
  '',
].join('\n');
fs.writeFileSync(path.join(DART_OUT_DIR, 'models.dart'), barrel, 'utf8');
console.log('  generated: models.dart');

console.log(`\nDone — ${exported.length} Dart model(s) + barrel written to ${DART_OUT_DIR}`);
