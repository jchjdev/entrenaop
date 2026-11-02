"""Catálogo profesional de ensayo v3: céntimos enteros y ofertas inmutables.

El servidor publica estas ofertas; Flutter y la web no calculan ni conceden
derechos. El mapeo Stripe debe proceder de lecturas verificadas del sandbox.
"""
import argparse
import json
from pathlib import Path
from uuid import NAMESPACE_URL, uuid5

VERSION = '20261102_v3'
BANDS = ((6, 10), (11, 20), (21, 35), (36, 50), (51, 75), (76, 100))
BASE = {'basic': 1290, 'professional': 1990, 'complete': 2490, 'basic_directory': 1780}
RATES = {
    'basic': (100, 80, 60, 40, 35, 25),
    'professional': (120, 100, 70, 50, 45, 35),
    'complete': (140, 120, 90, 70, 55, 45),
    'basic_directory': (100, 80, 60, 40, 35, 25),
}
TITLES = {'basic': 'Básico', 'professional': 'Profesional', 'complete': 'Completo', 'basic_directory': 'Básico con directorio'}
REUSED = {
    'basic': ('a8bc43e2-24a0-569a-9a2f-ec148491c59a', 'price_1UWfkaPhGz4xntMQyLepJiBH'),
    'professional': ('5c36e578-2a01-5205-9621-061326c9698a', 'price_1UWflAPhGz4xntMQ3la93nyc'),
    'complete': ('641381ab-180b-5622-8164-fa80620067a0', 'price_1UWflNPhGz4xntMQu8kJAvSR'),
    'basic_directory': ('0147fe6f-e04f-53d8-a9c7-17b912ec9f00', 'price_1UWflZPhGz4xntMQk60SIN7l'),
}


def amount(tier: str, capacity: int) -> int:
    if type(capacity) is not int or not 5 <= capacity <= 100:
        raise ValueError('El cupo debe ser un entero de 5 a 100.')
    return BASE[tier] + sum(max(0, min(capacity, last) - first + 1) * rate
                            for (first, last), rate in zip(BANDS, RATES[tier]))


def offer_id(tier: str, capacity: int) -> str:
    return REUSED[tier][0] if capacity == 5 else str(uuid5(NAMESPACE_URL, f'entrenaop-dev:trainer:{VERSION}:{tier}:{capacity}'))


def catalogue() -> dict:
    return {
        'version': VERSION, 'environment': 'entrenaop-dev', 'sandbox': True,
        'currency': 'EUR', 'interval': 'month', 'minimum_capacity': 5,
        'maximum_capacity': 100, 'capacity_step': 1,
        'tax_status': 'Pendiente de fijar el PVP fiscal antes de vender.',
        'billing': 'Cuota fija por cupo contratado, no por altas ni alumnos usados.',
        'commercial_entitlements': 'Solo herramientas y cupo en este ensayo. Pro/directorio por plan y asistente pendientes.',
        'included_capacity': 5, 'base_cents': BASE,
        'marginal_bands': [
            {'from': first, 'to': last, 'cents_per_additional_seat': {tier: rates[i] for tier, rates in RATES.items()}}
            for i, (first, last) in enumerate(BANDS)
        ],
        'monthly_prices': [
            {'capacity': n, **{tier: amount(tier, n) for tier in BASE}}
            for n in range(5, 101)
        ],
    }


def migration(mapping: list[dict]) -> str:
    expected = {(tier, n) for tier in BASE for n in range(5, 101)}
    indexed = {(r['tier'], r['capacity']): r for r in mapping}
    if len(mapping) != len(expected) or set(indexed) != expected:
        raise ValueError('Mapeo incompleto o duplicado: se necesitan 384 ofertas.')
    ids = []
    rows = []
    prices = set()
    for tier, n in sorted(expected):
        r = indexed[tier, n]
        price = r['priceId']
        if not isinstance(price, str) or not price.startswith('price_') or not price.replace('_', '').isalnum() or price in prices:
            raise ValueError('Identidad Stripe ausente, inválida o duplicada.')
        if r['amount'] != amount(tier, n) or (n == 5 and price != REUSED[tier][1]):
            raise ValueError('Importe o precio reutilizado incoherente.')
        prices.add(price)
        oid = offer_id(tier, n)
        ids.append(oid)
        if n == 5:
            continue  # No cambiar versiones ligadas a pedidos ya preparados.
        plan = 'basic' if tier == 'basic_directory' else tier
        directory = 'true' if tier != 'basic' else 'false'
        rows.append(f" ('{oid}',3,'{TITLES[tier]} · {n} alumnos · ensayo','{price}',{r['amount']},'EUR','month',{n},true,'{plan}',{directory})")
    allowed = ',\n '.join(f"'{oid}'" for oid in ids)
    return (
        'begin;\n-- Solo catálogo del ensayo Dev. No cambia contratos, coberturas pagadas ni regalos.\n'
        '-- Se mantienen las cuatro ofertas de cinco y todas las filas históricas.\n'
        'insert into commerce_private.offers(id,version,title,price_id,amount,currency,interval,capacity,active,plan_key,directory_option) values\n'
        + ',\n'.join(rows) + ';\n'
        '-- Las ofertas anteriores dejan de ser elegibles para nuevas compras. Sus precios\n'
        '-- Stripe siguen disponibles para conciliación de pedidos y renovaciones existentes.\n'
        "update commerce_private.offers set active=false where plan_key<>'legacy' and id not in (\n "
        + allowed + '\n);\ncommit;\n'
    )


def main() -> None:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--export', type=Path)
    parser.add_argument('--stripe-mapping', type=Path)
    parser.add_argument('--migration', type=Path)
    args = parser.parse_args()
    if args.export:
        args.export.parent.mkdir(parents=True, exist_ok=True)
        args.export.write_text(json.dumps(catalogue(), ensure_ascii=False, indent=2) + '\n', encoding='utf-8')
    if args.migration:
        if not args.stripe_mapping:
            parser.error('--migration requiere --stripe-mapping verificado.')
        args.migration.write_text(migration(json.loads(args.stripe_mapping.read_text(encoding='utf-8'))), encoding='utf-8')


if __name__ == '__main__':
    main()
