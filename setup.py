from setuptools import setup

with open("README.md", encoding="utf-8") as fh:
    long_description = fh.read()

setup(
    name="dify-python-sdk",
    version="0.1.12",
    author="yuanyouhui",
    author_email="yuanyouhuilyz@gmail.com",
    description="A package for interacting with the Dify Service-API (based on dify-client)",
    long_description=long_description,
    long_description_content_type="text/markdown",
    url="https://github.com/langgenius/dify",
    license="MIT",
    packages=["dify_client"],
    classifiers=[
        "Programming Language :: Python :: 3",
        "License :: OSI Approved :: MIT License",
        "Operating System :: OS Independent",
    ],
    python_requires=">=3.8",
    install_requires=["requests>=2.25.0,<3.0.0"],
    keywords="dify nlp ai language-processing",
    include_package_data=True,
)
