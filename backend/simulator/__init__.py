"""Simulateur kit IoT CityCare.

Parle à l'API, pas à Flutter. Ce n'est pas un bracelet réel, pas un suivi en direct.
"""

from simulator.scenario import DEMO_STEPS, SCHOOL
from simulator.seed import PARENT, YOUNG, seed_demo

__all__ = ["DEMO_STEPS", "PARENT", "SCHOOL", "YOUNG", "seed_demo"]
