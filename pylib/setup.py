from setuptools import setup, find_packages

setup(
    name='ofirydevops',
    version='0.1.0',
    author='Ofir Yahav',
    author_email='ofirydevops@gmail.com',
    packages=find_packages(),
    package_data={
        "ofirydevops": ["global_conf.yaml"]
    },
    include_package_data=True,
    install_requires=[
        'boto3>=1.37.3',
        'PyYAML>=6.0.2',
        'cerberus>=1.3.7',
        'aioboto3>=14.3.0',
        'polling2>=0.5.0'
    ]
)
