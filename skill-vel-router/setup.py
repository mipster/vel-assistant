from setuptools import setup

setup(
    name="skill-vel-router",
    version="0.1.0",
    package_dir={"": "."},
    install_requires=["ovos-workshop"],
    entry_points={
        "opm.skill": ["skill-vel-router.maciej=__init__:VelRouterSkill"]
    },
)
